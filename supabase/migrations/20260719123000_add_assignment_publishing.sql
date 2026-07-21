-- 以單一交易發布作業並保存學生對象快照。

begin;

create or replace function public.publish_contact_book_assignment(
  p_class_subject_id uuid,
  p_academic_term_id uuid,
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
  publisher public.contact_book_profiles%rowtype;
  target_class_id uuid;
  created_assignment public.assignments%rowtype;
  recipient_count integer;
begin
  if not public.can_publish_subject(p_class_subject_id) then
    raise exception 'publish_permission_required' using errcode = '42501';
  end if;
  if char_length(trim(p_content)) < 1 or char_length(trim(p_content)) > 1000
    or p_due_at < p_assignment_date::timestamptz
    or p_target_type not in ('common', 'group')
    or (p_target_type = 'group' and upper(trim(p_target_group_code)) not in ('A', 'B'))
    or (p_target_type = 'common' and p_target_group_code is not null) then
    raise exception 'invalid_assignment_data';
  end if;
  select p.* into publisher from public.contact_book_profiles p
  where p.id = auth.uid() and p.approval_status = 'approved' and p.is_active;
  if not found then raise exception 'invalid_publisher'; end if;
  select cs.class_id into target_class_id
  from public.class_subjects cs
  join public.classes c on c.id = cs.class_id and c.is_active
  join public.academic_terms term on term.id = p_academic_term_id
    and term.academic_year_id = c.academic_year_id
  where cs.id = p_class_subject_id and cs.is_active
    and p_assignment_date between term.starts_on and term.ends_on;
  if target_class_id is null then raise exception 'invalid_class_subject_term'; end if;
  insert into public.assignments (
    class_subject_id, academic_term_id, assignment_date, content, due_at,
    target_type, target_group_code, published_by, published_by_display_name
  ) values (
    p_class_subject_id, p_academic_term_id, p_assignment_date, trim(p_content), p_due_at,
    p_target_type,
    case when p_target_type = 'group' then upper(trim(p_target_group_code)) else null end,
    publisher.id, publisher.display_name
  ) returning * into created_assignment;
  if p_target_type = 'common' then
    insert into public.assignment_recipients (assignment_id, student_id, audience_source)
    select created_assignment.id, s.id, 'common' from public.students s
    where s.class_id = target_class_id and s.is_active;
  else
    insert into public.assignment_recipients (
      assignment_id, student_id, audience_source, group_code_snapshot
    )
    select created_assignment.id, s.id, 'group_snapshot', ssg.group_code
    from public.students s
    join public.student_subject_groups ssg on ssg.student_id = s.id
      and ssg.class_subject_id = p_class_subject_id
      and ssg.academic_term_id = p_academic_term_id
      and ssg.effective_from <= p_assignment_date
      and (ssg.effective_to is null or ssg.effective_to >= p_assignment_date)
    where s.class_id = target_class_id and s.is_active
      and ssg.group_code = upper(trim(p_target_group_code));
  end if;
  get diagnostics recipient_count = row_count;
  if recipient_count = 0 then raise exception 'empty_assignment_audience'; end if;
  return jsonb_build_object(
    'id', created_assignment.id, 'recipientCount', recipient_count,
    'targetType', created_assignment.target_type,
    'targetGroupCode', created_assignment.target_group_code
  );
end;
$$;

revoke all on function public.publish_contact_book_assignment(
  uuid, uuid, date, text, timestamptz, text, text
) from public, anon, authenticated;
grant execute on function public.publish_contact_book_assignment(
  uuid, uuid, date, text, timestamptz, text, text
) to authenticated;

commit;
