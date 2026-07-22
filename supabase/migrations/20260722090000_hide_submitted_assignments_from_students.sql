-- Hide submitted assignments from each student while preserving staff history.
-- Keep a made-up reminder visible to the student for one day.

begin;

alter table public.assignment_recipients
  add column if not exists submitted_at timestamptz;

comment on column public.assignment_recipients.submitted_at is
  'The time this recipient was recorded as submitted. Null means the student still needs to see the assignment.';

with latest_checks as (
  select submission_check.assignment_id, max(submission_check.checked_at) as checked_at
  from public.submission_checks submission_check
  group by submission_check.assignment_id
)
update public.assignment_recipients recipient
set submitted_at = coalesce(
  (
    select exception.resolved_at
    from public.submission_exceptions exception
    where exception.assignment_id = recipient.assignment_id
      and exception.student_id = recipient.student_id
      and exception.workflow_state in ('made_up', 'waived')
  ),
  latest_check.checked_at
)
from latest_checks latest_check
where recipient.assignment_id = latest_check.assignment_id
  and recipient.submitted_at is null
  and not exists (
    select 1
    from public.submission_exceptions open_exception
    where open_exception.assignment_id = recipient.assignment_id
      and open_exception.student_id = recipient.student_id
      and open_exception.workflow_state = 'open'
  );

update public.submission_exceptions exception
set hide_after = exception.resolved_at + interval '1 day'
where exception.workflow_state in ('made_up', 'waived')
  and exception.resolved_at is not null
  and exception.hide_after is distinct from exception.resolved_at + interval '1 day';

create or replace function public.prepare_submission_exception()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.initial_reason in ('incomplete', 'not_brought') then
      new.counts_as_missing = true;
    elsif new.initial_reason = 'late' then
      new.counts_as_late = true;
    end if;
  end if;

  if new.workflow_state in ('made_up', 'waived') then
    new.resolved_at = coalesce(new.resolved_at, now());
    new.hide_after = coalesce(new.hide_after, new.resolved_at + interval '1 day');
  else
    new.resolved_at = null;
    new.hide_after = null;
  end if;

  new.updated_at = now();
  return new;
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

  update public.assignment_recipients recipient
  set submitted_at = case
    when exists (
      select 1
      from jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
        as item(student_id uuid, reason text, follow_up_due_at timestamptz)
      where item.student_id = recipient.student_id
    ) then null
    else now()
  end
  where recipient.assignment_id = p_assignment_id;

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

revoke all on function public.record_assignment_submission_check(uuid, text, text, jsonb)
  from public, anon, authenticated;

commit;
