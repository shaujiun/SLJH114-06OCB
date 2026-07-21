-- Student helpers may create first-stage exceptions, but only teachers and
-- administrators may revise or resolve an exception that already exists.

begin;

create or replace function public.record_assignment_submission_check_v2(
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
begin
  if p_stage = 'helper'
    and jsonb_typeof(coalesce(p_exceptions, '[]'::jsonb)) = 'array' then
    if exists (
      select 1
      from public.submission_exceptions exception
      join jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
        as item(student_id uuid, reason text, follow_up_due_at timestamptz)
        on item.student_id = exception.student_id
      where exception.assignment_id = p_assignment_id
        and (
          exception.workflow_state <> 'open'
          or exception.current_reason is distinct from item.reason
          or exception.follow_up_due_at is distinct from item.follow_up_due_at
        )
    ) or exists (
      select 1
      from public.submission_exceptions exception
      where exception.assignment_id = p_assignment_id
        and exception.workflow_state = 'open'
        and not exists (
          select 1
          from jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
            as item(student_id uuid, reason text, follow_up_due_at timestamptz)
          where item.student_id = exception.student_id
        )
    ) then
      raise exception 'helper_cannot_modify_existing_exception' using errcode = '42501';
    end if;
  end if;

  return public.record_assignment_submission_check(
    p_assignment_id,
    p_stage,
    p_result,
    p_exceptions
  );
end;
$$;

revoke all on function public.record_assignment_submission_check_v2(
  uuid, text, text, jsonb
) from public, anon, authenticated;
grant execute on function public.record_assignment_submission_check_v2(
  uuid, text, text, jsonb
) to authenticated;

revoke execute on function public.record_assignment_submission_check(
  uuid, text, text, jsonb
) from authenticated;

commit;
