-- Allow staff to mark one assignment recipient as submitted without changing
-- the rest of the class. Submissions completed by the original due time do not
-- become late merely because an earlier exception was recorded.
begin;

create or replace function public.record_individual_assignment_submission(
  p_assignment_id uuid,
  p_student_id uuid,
  p_stage text default 'teacher'
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
  where assignment.id = p_assignment_id
    and assignment.is_active
  for update;
  if not found then raise exception 'invalid_assignment'; end if;

  if p_stage not in ('helper', 'teacher') then
    raise exception 'invalid_submission_check';
  end if;
  if not public.can_access_assignment_as_staff(p_assignment_id)
    or (p_stage = 'teacher' and not public.can_manage_subject(target_assignment.class_subject_id)) then
    raise exception 'submission_permission_required' using errcode = '42501';
  end if;
  if not exists (
    select 1
    from public.assignment_recipients recipient
    where recipient.assignment_id = p_assignment_id
      and recipient.student_id = p_student_id
  ) then
    raise exception 'invalid_assignment_recipient';
  end if;

  select * into target_exception
  from public.submission_exceptions exception
  where exception.assignment_id = p_assignment_id
    and exception.student_id = p_student_id
  for update;

  if target_exception.id is not null
    and target_exception.workflow_state = 'open'
    and p_stage = 'helper' then
    raise exception 'helper_cannot_resolve_existing_exception' using errcode = '42501';
  end if;

  if target_exception.id is not null and target_exception.workflow_state = 'open' then
    resolved_as_late := target_exception.counts_as_late
      or target_exception.current_reason = 'late'
      or (
        target_exception.current_reason in ('leave', 'official_leave')
        and target_exception.follow_up_due_at is not null
        and now() > target_exception.follow_up_due_at
      )
      or (
        target_exception.current_reason not in ('leave', 'official_leave', 'retest_required')
        and now() > target_assignment.due_at
      );

    update public.submission_exceptions exception
    set workflow_state = 'made_up',
        counts_as_late = resolved_as_late,
        last_updated_by = auth.uid()
    where exception.id = target_exception.id;
  end if;

  update public.assignment_recipients recipient
  set submitted_at = now()
  where recipient.assignment_id = p_assignment_id
    and recipient.student_id = p_student_id;

  select count(*) into open_count
  from public.submission_exceptions exception
  where exception.assignment_id = p_assignment_id
    and exception.workflow_state = 'open';

  return jsonb_build_object(
    'assignmentId', p_assignment_id,
    'studentId', p_student_id,
    'stage', p_stage,
    'countsAsLate', resolved_as_late,
    'openExceptionCount', open_count
  );
end;
$$;

revoke all on function public.record_individual_assignment_submission(uuid, uuid, text)
  from public, anon;
grant execute on function public.record_individual_assignment_submission(uuid, uuid, text)
  to authenticated;

commit;
