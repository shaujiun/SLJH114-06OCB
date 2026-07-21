-- Split mathematics and English student-helper permissions by A/B group.

begin;

alter table public.student_helper_assignments
  add column if not exists target_group_code citext;

alter table public.student_helper_assignments
  drop constraint if exists helper_target_group_valid;
alter table public.student_helper_assignments
  add constraint helper_target_group_valid check (
    target_group_code is null or upper(trim(target_group_code::text)) in ('A', 'B')
  );

-- Preserve any existing mathematics or English helper by assigning the
-- student's own group for that term when it can be determined.
update public.student_helper_assignments sha
set target_group_code = (
  select ssg.group_code
  from public.student_subject_groups ssg
  where ssg.student_id = sha.student_id
    and ssg.class_subject_id = sha.class_subject_id
    and ssg.academic_term_id = sha.academic_term_id
  order by ssg.effective_from desc
  limit 1
)
where sha.helper_role = 'subject_helper'
  and sha.target_group_code is null
  and exists (
    select 1
    from public.class_subjects cs
    join public.subjects subject on subject.id = cs.subject_id
    where cs.id = sha.class_subject_id
      and subject.code in ('math', 'english')
  );

create or replace function public.admin_update_student_settings_v2(
  p_student_id uuid,
  p_academic_term_id uuid,
  p_math_group text,
  p_english_group text,
  p_is_homework_leader boolean,
  p_helper_assignments jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_student public.students%rowtype;
  base_result jsonb;
  requested_count integer;
  unique_count integer;
  valid_count integer;
begin
  if not public.contact_book_is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;
  if jsonb_typeof(coalesce(p_helper_assignments, '[]'::jsonb)) <> 'array' then
    raise exception 'invalid_helper_assignments';
  end if;

  select * into target_student
  from public.students s
  where s.id = p_student_id and s.is_active;
  if not found then raise exception 'invalid_student'; end if;

  select count(*), count(distinct requested.class_subject_id), count(valid_subject.id)
  into requested_count, unique_count, valid_count
  from jsonb_to_recordset(coalesce(p_helper_assignments, '[]'::jsonb))
    as requested(class_subject_id uuid, target_group_code text)
  left join public.class_subjects valid_subject
    on valid_subject.id = requested.class_subject_id
    and valid_subject.class_id = target_student.class_id
    and valid_subject.is_active
  left join public.subjects subject on subject.id = valid_subject.subject_id
  where requested.class_subject_id is not null
    and (
      (subject.code in ('math', 'english')
        and upper(trim(requested.target_group_code)) in ('A', 'B'))
      or (subject.code not in ('math', 'english') and requested.target_group_code is null)
    );

  if requested_count <> jsonb_array_length(coalesce(p_helper_assignments, '[]'::jsonb))
    or unique_count <> requested_count
    or valid_count <> requested_count then
    raise exception 'invalid_helper_assignments';
  end if;

  select public.admin_update_student_settings(
    p_student_id,
    p_academic_term_id,
    p_math_group,
    p_english_group,
    p_is_homework_leader,
    array[]::uuid[]
  ) into base_result;

  insert into public.student_helper_assignments (
    student_id,
    academic_term_id,
    class_subject_id,
    helper_role,
    target_group_code,
    starts_on,
    ends_on,
    created_by
  )
  select
    p_student_id,
    p_academic_term_id,
    requested.class_subject_id,
    'subject_helper',
    case when requested.target_group_code is null
      then null else upper(trim(requested.target_group_code)) end,
    term.starts_on,
    term.ends_on,
    auth.uid()
  from jsonb_to_recordset(coalesce(p_helper_assignments, '[]'::jsonb))
    as requested(class_subject_id uuid, target_group_code text)
  join public.academic_terms term on term.id = p_academic_term_id;

  return base_result || jsonb_build_object('helperAssignmentCount', requested_count);
end;
$$;

revoke all on function public.admin_update_student_settings_v2(
  uuid, uuid, text, text, boolean, jsonb
) from public, anon, authenticated;
grant execute on function public.admin_update_student_settings_v2(
  uuid, uuid, text, text, boolean, jsonb
) to authenticated;

create or replace function public.can_publish_assignment_target(
  target_class_subject_id uuid,
  target_academic_term_id uuid,
  requested_target_type text,
  requested_target_group_code text
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
    from public.student_helper_assignments sha
    join public.students student on student.id = sha.student_id
    join public.contact_book_profiles profile on profile.id = student.profile_id
    join public.academic_terms term on term.id = sha.academic_term_id
    where sha.class_subject_id = target_class_subject_id
      and sha.academic_term_id = target_academic_term_id
      and sha.helper_role = 'subject_helper'
      and student.profile_id = auth.uid()
      and (
        current_date between term.starts_on and term.ends_on
        or term.id = (
          select upcoming.id from public.academic_terms upcoming
          where upcoming.academic_year_id = term.academic_year_id
            and upcoming.starts_on > current_date
          order by upcoming.starts_on limit 1
        )
      )
      and (
        (sha.target_group_code is null and requested_target_type = 'common')
        or (
          sha.target_group_code is not null
          and requested_target_type = 'group'
          and upper(trim(requested_target_group_code)) = upper(sha.target_group_code::text)
        )
      )
      and student.is_active
      and profile.approval_status = 'approved'
      and profile.is_active
  )
  or exists (
    select 1
    from public.student_helper_assignments sha
    join public.students student on student.id = sha.student_id
    join public.contact_book_profiles profile on profile.id = student.profile_id
    join public.academic_terms term on term.id = sha.academic_term_id
    join public.class_subjects cs on cs.id = target_class_subject_id
      and cs.class_id = student.class_id
    where sha.academic_term_id = target_academic_term_id
      and sha.helper_role = 'homework_leader'
      and sha.class_subject_id is null
      and student.profile_id = auth.uid()
      and (
        current_date between term.starts_on and term.ends_on
        or term.id = (
          select upcoming.id from public.academic_terms upcoming
          where upcoming.academic_year_id = term.academic_year_id
            and upcoming.starts_on > current_date
          order by upcoming.starts_on limit 1
        )
      )
      and student.is_active
      and profile.approval_status = 'approved'
      and profile.is_active
  );
$$;

revoke all on function public.can_publish_assignment_target(uuid, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.can_publish_assignment_target(uuid, uuid, text, text)
  to authenticated;

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
      and public.can_publish_assignment_target(
        assignment.class_subject_id,
        assignment.academic_term_id,
        assignment.target_type,
        assignment.target_group_code::text
      )
  );
$$;

revoke all on function public.can_access_assignment_as_staff(uuid)
  from public, anon, authenticated;
grant execute on function public.can_access_assignment_as_staff(uuid)
  to authenticated;

create or replace function public.can_read_assignment_recipients_as_staff(
  target_assignment_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_access_assignment_as_staff(target_assignment_id);
$$;

drop policy if exists assignments_read_allowed on public.assignments;
create policy assignments_read_allowed on public.assignments
for select to authenticated using (
  public.can_access_assignment_as_staff(id)
  or (is_active and public.is_current_student_assignment_recipient(id))
);

drop policy if exists assignments_publish on public.assignments;
create policy assignments_publish on public.assignments
for insert to authenticated with check (
  public.can_manage_subject(class_subject_id) and published_by = auth.uid()
);

drop policy if exists assignments_update_staff_or_owner_helper on public.assignments;
create policy assignments_update_staff_or_owner_helper on public.assignments
for update to authenticated
using (public.can_manage_subject(class_subject_id))
with check (public.can_manage_subject(class_subject_id));

drop policy if exists submission_checks_read_allowed on public.submission_checks;
create policy submission_checks_read_allowed on public.submission_checks
for select to authenticated using (public.can_access_assignment_as_staff(assignment_id));

drop policy if exists submission_checks_insert_allowed on public.submission_checks;
create policy submission_checks_insert_allowed on public.submission_checks
for insert to authenticated with check (
  checked_by = auth.uid() and public.can_access_assignment_as_staff(assignment_id)
);

drop policy if exists exceptions_read_allowed on public.submission_exceptions;
create policy exceptions_read_allowed on public.submission_exceptions
for select to authenticated using (
  public.is_student_self(student_id)
  or public.can_access_assignment_as_staff(assignment_id)
);

drop policy if exists exceptions_insert_allowed on public.submission_exceptions;
create policy exceptions_insert_allowed on public.submission_exceptions
for insert to authenticated with check (
  first_recorded_by = auth.uid()
  and last_updated_by = auth.uid()
  and public.can_access_assignment_as_staff(assignment_id)
);

drop policy if exists exception_events_read_allowed on public.submission_status_events;
create policy exception_events_read_allowed on public.submission_status_events
for select to authenticated using (
  exists (
    select 1
    from public.submission_exceptions exception
    where exception.id = submission_exception_id
      and (
        public.is_student_self(exception.student_id)
        or public.can_access_assignment_as_staff(exception.assignment_id)
      )
  )
);

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
  if not public.can_publish_assignment_target(
    p_class_subject_id, p_academic_term_id, p_target_type, p_target_group_code
  ) then
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
  where cs.id = p_class_subject_id and cs.is_active;
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
    select created_assignment.id, student.id, 'common'
    from public.students student
    where student.class_id = target_class_id and student.is_active;
  else
    insert into public.assignment_recipients (
      assignment_id, student_id, audience_source, group_code_snapshot
    )
    select created_assignment.id, student.id, 'group_snapshot', selected_group.group_code
    from public.students student
    join lateral (
      select student_group.group_code
      from public.student_subject_groups student_group
      where student_group.student_id = student.id
        and student_group.class_subject_id = p_class_subject_id
        and student_group.academic_term_id = p_academic_term_id
      order by
        case when student_group.effective_from <= p_assignment_date
          and (student_group.effective_to is null or student_group.effective_to >= p_assignment_date)
          then 0 else 1 end,
        abs(student_group.effective_from - p_assignment_date),
        student_group.effective_from desc
      limit 1
    ) selected_group on true
    where student.class_id = target_class_id
      and student.is_active
      and selected_group.group_code = upper(trim(p_target_group_code));
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

create or replace function public.record_assignment_submission_check(
  p_assignment_id uuid,
  p_stage text,
  p_result text,
  p_exceptions jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_assignment public.assignments%rowtype;
  requested_count integer;
  unique_count integer;
  open_count integer;
begin
  select * into target_assignment from public.assignments assignment
  where assignment.id = p_assignment_id and assignment.is_active for update;
  if not found then raise exception 'invalid_assignment'; end if;
  if p_stage not in ('helper', 'teacher')
    or p_result not in ('all_submitted', 'exceptions_recorded')
    or jsonb_typeof(coalesce(p_exceptions, '[]'::jsonb)) <> 'array' then
    raise exception 'invalid_submission_check';
  end if;
  if not public.can_access_assignment_as_staff(p_assignment_id)
    or (p_stage = 'teacher' and not public.can_manage_subject(target_assignment.class_subject_id)) then
    raise exception 'submission_permission_required' using errcode = '42501';
  end if;

  select count(*), count(distinct item.student_id) into requested_count, unique_count
  from jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
    as item(student_id uuid, reason text, follow_up_due_at timestamptz);
  if requested_count <> unique_count
    or (p_result = 'all_submitted' and requested_count <> 0)
    or (p_result = 'exceptions_recorded' and requested_count = 0)
    or exists (
      select 1 from jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
        as item(student_id uuid, reason text, follow_up_due_at timestamptz)
      where item.reason not in ('incomplete', 'not_brought', 'late', 'leave', 'official_leave', 'exempt')
        or (item.reason in ('leave', 'official_leave') and item.follow_up_due_at is null)
        or not exists (
          select 1 from public.assignment_recipients recipient
          where recipient.assignment_id = p_assignment_id
            and recipient.student_id = item.student_id
        )
    ) then raise exception 'invalid_submission_exceptions'; end if;

  insert into public.submission_checks (assignment_id, check_stage, result, checked_by, checked_at)
  values (p_assignment_id, p_stage, p_result, auth.uid(), now())
  on conflict (assignment_id, check_stage) do update
  set result = excluded.result, checked_by = excluded.checked_by, checked_at = excluded.checked_at;

  if p_stage = 'teacher' then
    update public.submission_exceptions exception
    set workflow_state = 'made_up',
        counts_as_late = exception.counts_as_late or not (
          exception.current_reason in ('leave', 'official_leave')
          and exception.follow_up_due_at is not null and now() <= exception.follow_up_due_at
        ),
        last_updated_by = auth.uid()
    where exception.assignment_id = p_assignment_id and exception.workflow_state = 'open'
      and (p_result = 'all_submitted' or not exists (
        select 1 from jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
          as item(student_id uuid, reason text, follow_up_due_at timestamptz)
        where item.student_id = exception.student_id
      ));
  end if;

  if p_result = 'exceptions_recorded' then
    insert into public.submission_exceptions (
      assignment_id, student_id, initial_reason, current_reason, workflow_state,
      follow_up_due_at, counts_as_missing, counts_as_late, first_recorded_by, last_updated_by
    )
    select p_assignment_id, item.student_id, item.reason, item.reason, 'open', item.follow_up_due_at,
      item.reason in ('incomplete', 'not_brought'), item.reason = 'late', auth.uid(), auth.uid()
    from jsonb_to_recordset(p_exceptions)
      as item(student_id uuid, reason text, follow_up_due_at timestamptz)
    on conflict (assignment_id, student_id) do update
    set current_reason = excluded.current_reason,
        workflow_state = 'open',
        follow_up_due_at = excluded.follow_up_due_at,
        counts_as_missing = submission_exceptions.counts_as_missing or excluded.counts_as_missing,
        counts_as_late = submission_exceptions.counts_as_late or excluded.counts_as_late,
        last_updated_by = auth.uid();
  end if;

  select count(*) into open_count from public.submission_exceptions exception
  where exception.assignment_id = p_assignment_id and exception.workflow_state = 'open';
  return jsonb_build_object(
    'assignmentId', p_assignment_id,
    'stage', p_stage,
    'result', p_result,
    'exceptionCount', requested_count,
    'openExceptionCount', open_count
  );
end;
$$;

revoke all on function public.publish_contact_book_assignment(
  uuid, uuid, date, text, timestamptz, text, text
) from public, anon, authenticated;
grant execute on function public.publish_contact_book_assignment(
  uuid, uuid, date, text, timestamptz, text, text
) to authenticated;

revoke all on function public.record_assignment_submission_check(uuid, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.record_assignment_submission_check(uuid, text, text, jsonb)
  to authenticated;

commit;
