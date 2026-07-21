-- Scope student-helper publishing and first-stage submission checks to the
-- exact term and subject selected by the administrator.

begin;

create or replace function public.can_publish_subject_for_term(
  target_class_subject_id uuid,
  target_academic_term_id uuid
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
    join public.students s on s.id = sha.student_id
    join public.contact_book_profiles p on p.id = s.profile_id
    join public.academic_terms term on term.id = sha.academic_term_id
    where sha.class_subject_id = target_class_subject_id
      and sha.academic_term_id = target_academic_term_id
      and sha.helper_role = 'subject_helper'
      and s.profile_id = auth.uid()
      and sha.starts_on <= greatest(current_date, term.starts_on)
      and (sha.ends_on is null or sha.ends_on >= greatest(current_date, term.starts_on))
      and s.is_active
      and p.approval_status = 'approved'
      and p.is_active
  )
  or exists (
    select 1
    from public.student_helper_assignments sha
    join public.students s on s.id = sha.student_id
    join public.contact_book_profiles p on p.id = s.profile_id
    join public.academic_terms term on term.id = sha.academic_term_id
    join public.class_subjects cs on cs.id = target_class_subject_id
      and cs.class_id = s.class_id
    where sha.academic_term_id = target_academic_term_id
      and sha.helper_role = 'homework_leader'
      and sha.class_subject_id is null
      and s.profile_id = auth.uid()
      and sha.starts_on <= greatest(current_date, term.starts_on)
      and (sha.ends_on is null or sha.ends_on >= greatest(current_date, term.starts_on))
      and s.is_active
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;

revoke all on function public.can_publish_subject_for_term(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.can_publish_subject_for_term(uuid, uuid)
  to authenticated;

create or replace function public.can_view_class_roster(target_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_manage_class(target_class_id) or exists (
    select 1
    from public.class_staff_assignments csa
    join public.contact_book_profiles p on p.id = csa.profile_id
    join public.classes c on c.id = csa.class_id
    join public.academic_years ay on ay.id = c.academic_year_id
    where csa.class_id = target_class_id
      and csa.profile_id = auth.uid()
      and csa.starts_on <= greatest(current_date, ay.starts_on)
      and (csa.ends_on is null or csa.ends_on >= greatest(current_date, ay.starts_on))
      and p.approval_status = 'approved'
      and p.is_active
  ) or exists (
    select 1
    from public.student_helper_assignments sha
    join public.students s on s.id = sha.student_id
    join public.academic_terms term on term.id = sha.academic_term_id
    join public.contact_book_profiles p on p.id = s.profile_id
    where s.profile_id = auth.uid()
      and s.class_id = target_class_id
      and sha.starts_on <= greatest(current_date, term.starts_on)
      and (sha.ends_on is null or sha.ends_on >= greatest(current_date, term.starts_on))
      and s.is_active
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;

create or replace function public.can_read_assignment_recipients_as_staff(
  target_assignment_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.assignments a
    where a.id = target_assignment_id
      and public.can_publish_subject_for_term(a.class_subject_id, a.academic_term_id)
  );
$$;

drop policy if exists assignments_read_allowed on public.assignments;
create policy assignments_read_allowed on public.assignments
for select to authenticated using (
  public.can_publish_subject_for_term(class_subject_id, academic_term_id)
  or (is_active and public.is_current_student_assignment_recipient(id))
);

drop policy if exists submission_checks_read_allowed on public.submission_checks;
create policy submission_checks_read_allowed on public.submission_checks
for select to authenticated using (
  exists (
    select 1 from public.assignments a
    where a.id = assignment_id
      and public.can_publish_subject_for_term(a.class_subject_id, a.academic_term_id)
  )
);

drop policy if exists submission_checks_insert_allowed on public.submission_checks;
create policy submission_checks_insert_allowed on public.submission_checks
for insert to authenticated with check (
  checked_by = auth.uid()
  and exists (
    select 1 from public.assignments a
    where a.id = assignment_id
      and public.can_publish_subject_for_term(a.class_subject_id, a.academic_term_id)
  )
);

drop policy if exists exceptions_read_allowed on public.submission_exceptions;
create policy exceptions_read_allowed on public.submission_exceptions
for select to authenticated using (
  public.is_student_self(student_id)
  or exists (
    select 1 from public.assignments a
    where a.id = assignment_id
      and public.can_publish_subject_for_term(a.class_subject_id, a.academic_term_id)
  )
);

drop policy if exists exceptions_insert_allowed on public.submission_exceptions;
create policy exceptions_insert_allowed on public.submission_exceptions
for insert to authenticated with check (
  first_recorded_by = auth.uid()
  and last_updated_by = auth.uid()
  and exists (
    select 1 from public.assignments a
    where a.id = assignment_id
      and public.can_publish_subject_for_term(a.class_subject_id, a.academic_term_id)
  )
);

drop policy if exists exception_events_read_allowed on public.submission_status_events;
create policy exception_events_read_allowed on public.submission_status_events
for select to authenticated using (
  exists (
    select 1
    from public.submission_exceptions se
    join public.assignments a on a.id = se.assignment_id
    where se.id = submission_exception_id
      and (
        public.is_student_self(se.student_id)
        or public.can_publish_subject_for_term(a.class_subject_id, a.academic_term_id)
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
  if not public.can_publish_subject_for_term(p_class_subject_id, p_academic_term_id) then
    raise exception 'publish_permission_required' using errcode = '42501';
  end if;
  if char_length(trim(p_content)) < 1 or char_length(trim(p_content)) > 1000
    or p_due_at < p_assignment_date::timestamptz
    or p_target_type not in ('common', 'group')
    or (p_target_type = 'group' and upper(trim(p_target_group_code)) not in ('A', 'B'))
    or (p_target_type = 'common' and p_target_group_code is not null) then
    raise exception 'invalid_assignment_data';
  end if;

  select p.* into publisher
  from public.contact_book_profiles p
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
    select created_assignment.id, s.id, 'common'
    from public.students s
    where s.class_id = target_class_id and s.is_active;
  else
    insert into public.assignment_recipients (
      assignment_id, student_id, audience_source, group_code_snapshot
    )
    select created_assignment.id, s.id, 'group_snapshot', selected_group.group_code
    from public.students s
    join lateral (
      select ssg.group_code
      from public.student_subject_groups ssg
      where ssg.student_id = s.id
        and ssg.class_subject_id = p_class_subject_id
        and ssg.academic_term_id = p_academic_term_id
      order by
        case when ssg.effective_from <= p_assignment_date
          and (ssg.effective_to is null or ssg.effective_to >= p_assignment_date)
          then 0 else 1 end,
        abs(ssg.effective_from - p_assignment_date),
        ssg.effective_from desc
      limit 1
    ) selected_group on true
    where s.class_id = target_class_id
      and s.is_active
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
  select * into target_assignment from public.assignments a
  where a.id = p_assignment_id and a.is_active for update;
  if not found then raise exception 'invalid_assignment'; end if;
  if p_stage not in ('helper', 'teacher')
    or p_result not in ('all_submitted', 'exceptions_recorded')
    or jsonb_typeof(coalesce(p_exceptions, '[]'::jsonb)) <> 'array' then
    raise exception 'invalid_submission_check';
  end if;
  if not public.can_publish_subject_for_term(
    target_assignment.class_subject_id,
    target_assignment.academic_term_id
  ) or (p_stage = 'teacher' and not public.can_manage_subject(target_assignment.class_subject_id)) then
    raise exception 'submission_permission_required' using errcode = '42501';
  end if;

  select count(*), count(distinct x.student_id) into requested_count, unique_count
  from jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
    as x(student_id uuid, reason text, follow_up_due_at timestamptz);
  if requested_count <> unique_count
    or (p_result = 'all_submitted' and requested_count <> 0)
    or (p_result = 'exceptions_recorded' and requested_count = 0)
    or exists (
      select 1 from jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
        as x(student_id uuid, reason text, follow_up_due_at timestamptz)
      where x.reason not in ('incomplete', 'not_brought', 'late', 'leave', 'official_leave', 'exempt')
        or (x.reason in ('leave', 'official_leave') and x.follow_up_due_at is null)
        or not exists (
          select 1 from public.assignment_recipients ar
          where ar.assignment_id = p_assignment_id and ar.student_id = x.student_id
        )
    ) then raise exception 'invalid_submission_exceptions'; end if;

  insert into public.submission_checks (assignment_id, check_stage, result, checked_by, checked_at)
  values (p_assignment_id, p_stage, p_result, auth.uid(), now())
  on conflict (assignment_id, check_stage) do update
  set result = excluded.result, checked_by = excluded.checked_by, checked_at = excluded.checked_at;

  if p_stage = 'teacher' then
    update public.submission_exceptions se
    set workflow_state = 'made_up',
        counts_as_late = se.counts_as_late or not (
          se.current_reason in ('leave', 'official_leave')
          and se.follow_up_due_at is not null and now() <= se.follow_up_due_at
        ),
        last_updated_by = auth.uid()
    where se.assignment_id = p_assignment_id and se.workflow_state = 'open'
      and (p_result = 'all_submitted' or not exists (
        select 1 from jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
          as x(student_id uuid, reason text, follow_up_due_at timestamptz)
        where x.student_id = se.student_id
      ));
  end if;

  if p_result = 'exceptions_recorded' then
    insert into public.submission_exceptions (
      assignment_id, student_id, initial_reason, current_reason, workflow_state,
      follow_up_due_at, counts_as_missing, counts_as_late, first_recorded_by, last_updated_by
    )
    select p_assignment_id, x.student_id, x.reason, x.reason, 'open', x.follow_up_due_at,
      x.reason in ('incomplete', 'not_brought'), x.reason = 'late', auth.uid(), auth.uid()
    from jsonb_to_recordset(p_exceptions)
      as x(student_id uuid, reason text, follow_up_due_at timestamptz)
    on conflict (assignment_id, student_id) do update
    set current_reason = excluded.current_reason,
        workflow_state = 'open',
        follow_up_due_at = excluded.follow_up_due_at,
        counts_as_missing = submission_exceptions.counts_as_missing or excluded.counts_as_missing,
        counts_as_late = submission_exceptions.counts_as_late or excluded.counts_as_late,
        last_updated_by = auth.uid();
  end if;

  select count(*) into open_count from public.submission_exceptions se
  where se.assignment_id = p_assignment_id and se.workflow_state = 'open';
  return jsonb_build_object(
    'assignmentId', p_assignment_id, 'stage', p_stage, 'result', p_result,
    'exceptionCount', requested_count, 'openExceptionCount', open_count
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
