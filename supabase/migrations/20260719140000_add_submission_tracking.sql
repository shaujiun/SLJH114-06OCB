begin;

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
  if not public.can_publish_subject(target_assignment.class_subject_id)
    or (p_stage = 'teacher' and not public.can_manage_subject(target_assignment.class_subject_id)) then
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

revoke all on function public.record_assignment_submission_check(uuid, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.record_assignment_submission_check(uuid, text, text, jsonb)
  to authenticated;

commit;
