begin;

alter table public.assignments
  drop constraint if exists assignments_target_type_check;
alter table public.assignments
  add constraint assignments_target_type_check
  check (target_type in ('common', 'group', 'individual'));

alter table public.assignments
  drop constraint if exists assignment_target_valid;
alter table public.assignments
  add constraint assignment_target_valid check (
    (target_type = 'common' and target_group_code is null)
    or (target_type = 'group' and target_group_code is not null)
    or (target_type = 'individual' and target_group_code is null)
  );

create or replace function public.can_publish_individual_assignment_target(
  target_class_subject_id uuid,
  target_academic_term_id uuid,
  target_assignment_date date,
  target_student_ids uuid[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_manage_subject(target_class_subject_id)
  or exists (
    select 1
    from public.student_helper_assignments helper
    join public.students helper_student on helper_student.id = helper.student_id
    join public.contact_book_profiles profile on profile.id = helper_student.profile_id
    join public.class_subjects class_subject on class_subject.id = target_class_subject_id
    where helper.academic_term_id = target_academic_term_id
      and helper.helper_role = 'homework_leader'
      and helper.class_subject_id is null
      and helper_student.profile_id = auth.uid()
      and helper_student.class_id = class_subject.class_id
      and helper.starts_on <= target_assignment_date
      and (helper.ends_on is null or helper.ends_on >= target_assignment_date)
      and helper_student.is_active
      and profile.approval_status = 'approved'
      and profile.is_active
  )
  or (
    exists (
      select 1
      from public.student_helper_assignments helper
      join public.students helper_student on helper_student.id = helper.student_id
      join public.contact_book_profiles profile on profile.id = helper_student.profile_id
      where helper.class_subject_id = target_class_subject_id
        and helper.academic_term_id = target_academic_term_id
        and helper.helper_role = 'subject_helper'
        and helper_student.profile_id = auth.uid()
        and helper.starts_on <= target_assignment_date
        and (helper.ends_on is null or helper.ends_on >= target_assignment_date)
        and helper_student.is_active
        and profile.approval_status = 'approved'
        and profile.is_active
    )
    and not exists (
      select 1
      from unnest(coalesce(target_student_ids, array[]::uuid[])) selected(student_id)
      where not exists (
        select 1
        from public.student_helper_assignments helper
        join public.students helper_student on helper_student.id = helper.student_id
        where helper.class_subject_id = target_class_subject_id
          and helper.academic_term_id = target_academic_term_id
          and helper.helper_role = 'subject_helper'
          and helper_student.profile_id = auth.uid()
          and helper.starts_on <= target_assignment_date
          and (helper.ends_on is null or helper.ends_on >= target_assignment_date)
          and (
            helper.target_group_code is null
            or exists (
              select 1
              from public.student_subject_groups student_group
              where student_group.student_id = selected.student_id
                and student_group.class_subject_id = target_class_subject_id
                and student_group.academic_term_id = target_academic_term_id
                and student_group.group_code = helper.target_group_code
                and student_group.effective_from <= target_assignment_date
                and (student_group.effective_to is null or student_group.effective_to >= target_assignment_date)
            )
          )
      )
    )
  );
$$;

create or replace function public.can_access_assignment_as_staff(target_assignment_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.assignments assignment
    where assignment.id = target_assignment_id
      and (
        (
          assignment.target_type = 'individual'
          and public.can_publish_individual_assignment_target(
            assignment.class_subject_id,
            assignment.academic_term_id,
            assignment.assignment_date,
            array(
              select recipient.student_id
              from public.assignment_recipients recipient
              where recipient.assignment_id = assignment.id
            )
          )
        )
        or (
          assignment.target_type <> 'individual'
          and public.can_publish_assignment_target(
            assignment.class_subject_id,
            assignment.academic_term_id,
            assignment.target_type,
            assignment.target_group_code::text
          )
        )
      )
  );
$$;

-- Replace the previous overloads instead of leaving two RPC signatures that
-- both accept calls without p_student_ids.
drop function if exists public.publish_contact_book_assignment(
  uuid, uuid, date, text, timestamptz, text, text
);

create or replace function public.publish_contact_book_assignment(
  p_class_subject_id uuid,
  p_academic_term_id uuid,
  p_assignment_date date,
  p_content text,
  p_due_at timestamptz,
  p_target_type text,
  p_target_group_code text default null,
  p_student_ids uuid[] default null
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
  requested_count integer;
begin
  if p_target_type = 'individual' then
    if not public.can_publish_individual_assignment_target(
      p_class_subject_id, p_academic_term_id, p_assignment_date, p_student_ids
    ) then raise exception 'publish_permission_required' using errcode = '42501'; end if;
  elsif not public.can_publish_assignment_target(
    p_class_subject_id, p_academic_term_id, p_target_type, p_target_group_code
  ) then
    raise exception 'publish_permission_required' using errcode = '42501';
  end if;

  if char_length(trim(p_content)) < 1
    or char_length(trim(p_content)) > 1000
    or p_due_at < p_assignment_date::timestamptz
    or p_target_type not in ('common', 'group', 'individual')
    or (p_target_type = 'group' and upper(trim(p_target_group_code)) not in ('A', 'B'))
    or (p_target_type <> 'group' and p_target_group_code is not null)
    or (p_target_type = 'individual' and coalesce(cardinality(p_student_ids), 0) = 0)
    or (p_target_type <> 'individual' and coalesce(cardinality(p_student_ids), 0) > 0) then
    raise exception 'invalid_assignment_data';
  end if;

  select profile.* into publisher
  from public.contact_book_profiles profile
  where profile.id = auth.uid()
    and profile.approval_status = 'approved'
    and profile.is_active;
  if not found then raise exception 'invalid_publisher'; end if;

  select class_subject.class_id into target_class_id
  from public.class_subjects class_subject
  join public.classes class on class.id = class_subject.class_id and class.is_active
  join public.academic_terms term
    on term.id = p_academic_term_id
    and term.academic_year_id = class.academic_year_id
  where class_subject.id = p_class_subject_id and class_subject.is_active;
  if target_class_id is null then raise exception 'invalid_class_subject_term'; end if;

  if p_target_type = 'individual' then
    select count(distinct selected.student_id) into requested_count
    from unnest(p_student_ids) selected(student_id);
    if requested_count <> cardinality(p_student_ids)
      or requested_count <> (
        select count(*) from public.students student
        where student.id = any(p_student_ids)
          and student.class_id = target_class_id
          and student.is_active
      ) then raise exception 'invalid_assignment_recipients'; end if;
  end if;

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
    select created_assignment.id, student.id, 'common'
    from public.students student
    where student.class_id = target_class_id and student.is_active;
  elsif p_target_type = 'group' then
    insert into public.assignment_recipients (
      assignment_id, student_id, audience_source, group_code_snapshot
    )
    select created_assignment.id, student.id, 'group_snapshot', student_group.group_code
    from public.students student
    join public.student_subject_groups student_group
      on student_group.student_id = student.id
      and student_group.class_subject_id = p_class_subject_id
      and student_group.academic_term_id = p_academic_term_id
      and student_group.effective_from <= p_assignment_date
      and (student_group.effective_to is null or student_group.effective_to >= p_assignment_date)
    where student.class_id = target_class_id
      and student.is_active
      and student_group.group_code = upper(trim(p_target_group_code));
  else
    insert into public.assignment_recipients (assignment_id, student_id, audience_source)
    select created_assignment.id, student.id, 'manual_adjustment'
    from public.students student
    where student.id = any(p_student_ids)
      and student.class_id = target_class_id
      and student.is_active;
  end if;

  get diagnostics recipient_count = row_count;
  if recipient_count = 0 then raise exception 'empty_assignment_audience'; end if;

  return jsonb_build_object(
    'id', created_assignment.id,
    'recipientCount', recipient_count,
    'targetType', created_assignment.target_type,
    'targetGroupCode', created_assignment.target_group_code
  );
end;
$$;

drop function if exists public.update_contact_book_assignment(
  uuid, date, text, timestamptz, text, text
);

create or replace function public.update_contact_book_assignment(
  p_assignment_id uuid,
  p_assignment_date date,
  p_content text,
  p_due_at timestamptz,
  p_target_type text,
  p_target_group_code text default null,
  p_student_ids uuid[] default null
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
  requested_count integer;
begin
  select * into target_assignment
  from public.assignments assignment
  where assignment.id = p_assignment_id and assignment.is_active
  for update;
  if not found then raise exception 'invalid_assignment'; end if;
  if not public.can_access_assignment_as_staff(p_assignment_id) then
    raise exception 'update_permission_required' using errcode = '42501';
  end if;

  normalized_group_code := case when p_target_type = 'group' then upper(trim(p_target_group_code)) else null end;
  if p_assignment_date is null or p_content is null or p_due_at is null
    or char_length(trim(p_content)) < 1 or char_length(trim(p_content)) > 1000
    or p_due_at < p_assignment_date::timestamptz
    or p_target_type not in ('common', 'group', 'individual')
    or (p_target_type = 'group' and normalized_group_code not in ('A', 'B'))
    or (p_target_type <> 'group' and p_target_group_code is not null)
    or (p_target_type = 'individual' and coalesce(cardinality(p_student_ids), 0) = 0)
    or (p_target_type <> 'individual' and coalesce(cardinality(p_student_ids), 0) > 0) then
    raise exception 'invalid_assignment_data';
  end if;

  select class_subject.class_id into target_class_id
  from public.class_subjects class_subject
  join public.classes class on class.id = class_subject.class_id and class.is_active
  where class_subject.id = target_assignment.class_subject_id;
  if target_class_id is null then raise exception 'invalid_class_subject_term'; end if;

  if p_target_type = 'individual' then
    select count(distinct selected.student_id) into requested_count
    from unnest(p_student_ids) selected(student_id);
    if requested_count <> cardinality(p_student_ids)
      or requested_count <> (
        select count(*) from public.students student
        where student.id = any(p_student_ids)
          and student.class_id = target_class_id
          and student.is_active
      ) then raise exception 'invalid_assignment_recipients'; end if;
    if not public.can_publish_individual_assignment_target(
      target_assignment.class_subject_id,
      target_assignment.academic_term_id,
      p_assignment_date,
      p_student_ids
    ) then raise exception 'update_target_permission_required' using errcode = '42501'; end if;
  elsif not public.can_publish_assignment_target(
    target_assignment.class_subject_id,
    target_assignment.academic_term_id,
    p_target_type,
    normalized_group_code
  ) then raise exception 'update_target_permission_required' using errcode = '42501'; end if;

  target_changed := target_assignment.target_type <> p_target_type
    or coalesce(upper(target_assignment.target_group_code::text), '') <> coalesce(normalized_group_code, '')
    or (
      p_target_type = 'individual' and (
        exists (
          select 1 from public.assignment_recipients recipient
          where recipient.assignment_id = p_assignment_id
            and not (recipient.student_id = any(p_student_ids))
        )
        or exists (
          select 1 from unnest(p_student_ids) selected(student_id)
          where not exists (
            select 1 from public.assignment_recipients recipient
            where recipient.assignment_id = p_assignment_id
              and recipient.student_id = selected.student_id
          )
        )
      )
    );

  if target_changed then
    select exists (
      select 1 from public.submission_checks submission_check
      where submission_check.assignment_id = p_assignment_id
    ) or exists (
      select 1 from public.submission_exceptions exception
      where exception.assignment_id = p_assignment_id
    ) or exists (
      select 1 from public.assignment_recipients recipient
      where recipient.assignment_id = p_assignment_id and recipient.submitted_at is not null
    ) into has_submission_activity;
    if has_submission_activity then raise exception 'assignment_target_locked'; end if;

    delete from public.assignment_recipients recipient where recipient.assignment_id = p_assignment_id;
    if p_target_type = 'common' then
      insert into public.assignment_recipients (assignment_id, student_id, audience_source)
      select p_assignment_id, student.id, 'common'
      from public.students student
      where student.class_id = target_class_id and student.is_active;
    elsif p_target_type = 'group' then
      insert into public.assignment_recipients (
        assignment_id, student_id, audience_source, group_code_snapshot
      )
      select p_assignment_id, student.id, 'group_snapshot', student_group.group_code
      from public.students student
      join public.student_subject_groups student_group
        on student_group.student_id = student.id
        and student_group.class_subject_id = target_assignment.class_subject_id
        and student_group.academic_term_id = target_assignment.academic_term_id
        and student_group.effective_from <= p_assignment_date
        and (student_group.effective_to is null or student_group.effective_to >= p_assignment_date)
      where student.class_id = target_class_id
        and student.is_active
        and student_group.group_code = normalized_group_code;
    else
      insert into public.assignment_recipients (assignment_id, student_id, audience_source)
      select p_assignment_id, student.id, 'manual_adjustment'
      from public.students student
      where student.id = any(p_student_ids)
        and student.class_id = target_class_id
        and student.is_active;
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

create or replace function public.record_individual_assignment_status(
  p_assignment_id uuid,
  p_student_id uuid,
  p_stage text,
  p_status text,
  p_follow_up_due_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_assignment public.assignments%rowtype;
  target_exception public.submission_exceptions%rowtype;
  open_count integer;
  resolved_as_late boolean := false;
begin
  select * into target_assignment
  from public.assignments assignment
  where assignment.id = p_assignment_id and assignment.is_active
  for update;
  if not found then raise exception 'invalid_assignment'; end if;
  if p_stage not in ('helper', 'teacher')
    or p_status not in (
      'pending', 'submitted', 'incomplete', 'not_brought', 'late',
      'retest_required', 'leave', 'official_leave', 'exempt'
    )
    or (p_status in ('leave', 'official_leave') and p_follow_up_due_at is null)
    or (p_status not in ('leave', 'official_leave') and p_follow_up_due_at is not null) then
    raise exception 'invalid_individual_status';
  end if;
  if not public.can_access_assignment_as_staff(p_assignment_id)
    or (p_stage = 'teacher' and not public.can_manage_subject(target_assignment.class_subject_id)) then
    raise exception 'submission_permission_required' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.assignment_recipients recipient
    where recipient.assignment_id = p_assignment_id and recipient.student_id = p_student_id
  ) then raise exception 'invalid_assignment_recipient'; end if;

  select * into target_exception
  from public.submission_exceptions exception
  where exception.assignment_id = p_assignment_id and exception.student_id = p_student_id
  for update;

  if p_stage = 'helper' and target_exception.id is not null
    and target_exception.workflow_state = 'open'
    and (p_status <> target_exception.current_reason or p_status in ('pending', 'submitted')) then
    raise exception 'helper_cannot_resolve_existing_exception' using errcode = '42501';
  end if;

  if p_status in ('pending', 'submitted') then
    if target_exception.id is not null and target_exception.workflow_state = 'open' then
      resolved_as_late := p_status = 'submitted' and (
        target_exception.counts_as_late
        or target_exception.current_reason = 'late'
        or (
          target_exception.current_reason in ('leave', 'official_leave')
          and target_exception.follow_up_due_at is not null
          and now() > target_exception.follow_up_due_at
        )
        or (
          target_exception.current_reason in ('incomplete', 'not_brought')
          and now() > target_assignment.due_at
        )
      );
      update public.submission_exceptions exception
      set workflow_state = 'made_up',
          counts_as_late = exception.counts_as_late or resolved_as_late,
          hide_after = case when p_status = 'pending' then now() else exception.hide_after end,
          last_updated_by = auth.uid()
      where exception.id = target_exception.id;

      if p_status = 'pending' then
        update public.submission_status_events status_event
        set note = 'reset_to_pending'
        where status_event.id = (
          select latest_event.id
          from public.submission_status_events latest_event
          where latest_event.submission_exception_id = target_exception.id
          order by latest_event.created_at desc, latest_event.id desc
          limit 1
        );
      end if;
    end if;
    update public.assignment_recipients recipient
    set submitted_at = case when p_status = 'submitted' then coalesce(recipient.submitted_at, now()) else null end
    where recipient.assignment_id = p_assignment_id and recipient.student_id = p_student_id;
  else
    insert into public.submission_exceptions (
      assignment_id, student_id, initial_reason, current_reason, workflow_state,
      follow_up_due_at, counts_as_missing, counts_as_late, first_recorded_by, last_updated_by
    ) values (
      p_assignment_id, p_student_id, p_status, p_status, 'open', p_follow_up_due_at,
      p_status in ('incomplete', 'not_brought'), p_status = 'late', auth.uid(), auth.uid()
    )
    on conflict (assignment_id, student_id) do update
    set current_reason = excluded.current_reason,
        workflow_state = 'open',
        follow_up_due_at = excluded.follow_up_due_at,
        counts_as_missing = submission_exceptions.counts_as_missing or excluded.counts_as_missing,
        counts_as_late = submission_exceptions.counts_as_late or excluded.counts_as_late,
        last_updated_by = auth.uid();

    update public.assignment_recipients recipient
    set submitted_at = case when p_status = 'exempt' then now() else null end
    where recipient.assignment_id = p_assignment_id and recipient.student_id = p_student_id;
  end if;

  select count(*) into open_count
  from public.submission_exceptions exception
  where exception.assignment_id = p_assignment_id
    and exception.workflow_state = 'open'
    and exception.current_reason <> 'exempt';

  return jsonb_build_object(
    'assignmentId', p_assignment_id,
    'studentId', p_student_id,
    'status', p_status,
    'countsAsLate', resolved_as_late,
    'openExceptionCount', open_count
  );
end;
$$;

revoke all on function public.can_publish_individual_assignment_target(uuid, uuid, date, uuid[])
  from public, anon, authenticated;
grant execute on function public.can_publish_individual_assignment_target(uuid, uuid, date, uuid[])
  to authenticated;

revoke all on function public.publish_contact_book_assignment(
  uuid, uuid, date, text, timestamptz, text, text, uuid[]
) from public, anon, authenticated;
grant execute on function public.publish_contact_book_assignment(
  uuid, uuid, date, text, timestamptz, text, text, uuid[]
) to authenticated;

revoke all on function public.update_contact_book_assignment(
  uuid, date, text, timestamptz, text, text, uuid[]
) from public, anon, authenticated;
grant execute on function public.update_contact_book_assignment(
  uuid, date, text, timestamptz, text, text, uuid[]
) to authenticated;

revoke all on function public.record_individual_assignment_status(uuid, uuid, text, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.record_individual_assignment_status(uuid, uuid, text, text, timestamptz)
  to authenticated;

commit;
