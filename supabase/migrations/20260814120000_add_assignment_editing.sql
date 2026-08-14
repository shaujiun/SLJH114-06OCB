begin;

create or replace function public.update_contact_book_assignment(
  p_assignment_id uuid,
  p_assignment_date date,
  p_content text,
  p_due_at timestamptz,
  p_target_type text,
  p_target_group_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_assignment public.assignments%rowtype;
  target_class_id uuid;
  normalized_group_code text;
  target_changed boolean;
  has_submission_activity boolean;
  recipient_count integer;
begin
  select * into target_assignment
  from public.assignments assignment
  where assignment.id = p_assignment_id and assignment.is_active
  for update;
  if not found then raise exception 'invalid_assignment'; end if;

  if not public.can_access_assignment_as_staff(p_assignment_id) then
    raise exception 'update_permission_required' using errcode = '42501';
  end if;

  normalized_group_code := case
    when p_target_type = 'group' then upper(trim(p_target_group_code))
    else null
  end;
  if p_assignment_date is null
    or p_content is null
    or p_due_at is null
    or p_target_type is null
    or char_length(trim(p_content)) < 1
    or char_length(trim(p_content)) > 1000
    or p_due_at < p_assignment_date::timestamptz
    or p_target_type not in ('common', 'group')
    or (
      p_target_type = 'group'
      and (normalized_group_code is null or normalized_group_code not in ('A', 'B'))
    )
    or (p_target_type = 'common' and p_target_group_code is not null) then
    raise exception 'invalid_assignment_data';
  end if;

  if not public.can_publish_assignment_target(
    target_assignment.class_subject_id,
    target_assignment.academic_term_id,
    p_target_type,
    normalized_group_code
  ) then
    raise exception 'update_target_permission_required' using errcode = '42501';
  end if;

  select class_subject.class_id into target_class_id
  from public.class_subjects class_subject
  join public.classes class on class.id = class_subject.class_id and class.is_active
  join public.academic_terms term
    on term.id = target_assignment.academic_term_id
    and term.academic_year_id = class.academic_year_id
  where class_subject.id = target_assignment.class_subject_id
    and class_subject.is_active;
  if target_class_id is null then raise exception 'invalid_class_subject_term'; end if;

  target_changed := target_assignment.target_type <> p_target_type
    or coalesce(upper(target_assignment.target_group_code::text), '')
      <> coalesce(normalized_group_code, '');

  if target_changed then
    select exists (
      select 1 from public.submission_checks submission_check
      where submission_check.assignment_id = p_assignment_id
    ) or exists (
      select 1 from public.submission_exceptions exception
      where exception.assignment_id = p_assignment_id
    ) or exists (
      select 1 from public.assignment_recipients recipient
      where recipient.assignment_id = p_assignment_id
        and recipient.submitted_at is not null
    ) into has_submission_activity;

    if has_submission_activity then raise exception 'assignment_target_locked'; end if;

    delete from public.assignment_recipients recipient
    where recipient.assignment_id = p_assignment_id;

    if p_target_type = 'common' then
      insert into public.assignment_recipients (assignment_id, student_id, audience_source)
      select p_assignment_id, student.id, 'common'
      from public.students student
      where student.class_id = target_class_id and student.is_active;
    else
      insert into public.assignment_recipients (
        assignment_id, student_id, audience_source, group_code_snapshot
      )
      select p_assignment_id, student.id, 'group_snapshot', selected_group.group_code
      from public.students student
      join lateral (
        select student_group.group_code
        from public.student_subject_groups student_group
        where student_group.student_id = student.id
          and student_group.class_subject_id = target_assignment.class_subject_id
          and student_group.academic_term_id = target_assignment.academic_term_id
        order by
          case when student_group.effective_from <= p_assignment_date
            and (
              student_group.effective_to is null
              or student_group.effective_to >= p_assignment_date
            )
            then 0 else 1 end,
          abs(student_group.effective_from - p_assignment_date),
          student_group.effective_from desc
        limit 1
      ) selected_group on true
      where student.class_id = target_class_id
        and student.is_active
        and upper(selected_group.group_code::text) = normalized_group_code;
    end if;

    get diagnostics recipient_count = row_count;
    if recipient_count = 0 then raise exception 'empty_assignment_audience'; end if;
  else
    select count(*) into recipient_count
    from public.assignment_recipients recipient
    where recipient.assignment_id = p_assignment_id;
  end if;

  update public.assignments assignment
  set assignment_date = p_assignment_date,
      content = trim(p_content),
      due_at = p_due_at,
      target_type = p_target_type,
      target_group_code = normalized_group_code
  where assignment.id = p_assignment_id;

  return jsonb_build_object(
    'id', p_assignment_id,
    'recipientCount', recipient_count,
    'targetChanged', target_changed,
    'targetType', p_target_type,
    'targetGroupCode', normalized_group_code
  );
end;
$$;

revoke all on function public.update_contact_book_assignment(
  uuid, date, text, timestamptz, text, text
) from public, anon, authenticated;
grant execute on function public.update_contact_book_assignment(
  uuid, date, text, timestamptz, text, text
) to authenticated;

commit;
