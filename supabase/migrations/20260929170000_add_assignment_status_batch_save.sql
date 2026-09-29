begin;

create or replace function public.record_assignment_statuses_batch(
  p_assignment_id uuid,
  p_stage text,
  p_updates jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  update_item jsonb;
  item_result jsonb;
  updated_count integer := 0;
  late_count integer := 0;
  open_count integer := 0;
begin
  if p_updates is null
    or jsonb_typeof(p_updates) <> 'array'
    or jsonb_array_length(p_updates) < 1
    or jsonb_array_length(p_updates) > 100 then
    raise exception 'invalid_status_batch';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_updates) item
    group by item->>'student_id'
    having item->>'student_id' is null or count(*) > 1
  ) then
    raise exception 'invalid_status_batch';
  end if;

  for update_item in select value from jsonb_array_elements(p_updates)
  loop
    item_result := public.record_individual_assignment_status(
      p_assignment_id,
      (update_item->>'student_id')::uuid,
      p_stage,
      update_item->>'status',
      nullif(update_item->>'follow_up_due_at', '')::timestamptz
    );
    updated_count := updated_count + 1;
    if coalesce((item_result->>'countsAsLate')::boolean, false) then
      late_count := late_count + 1;
    end if;
  end loop;

  select count(*) into open_count
  from public.submission_exceptions exception
  where exception.assignment_id = p_assignment_id
    and exception.workflow_state = 'open'
    and exception.current_reason <> 'exempt';

  return jsonb_build_object(
    'assignmentId', p_assignment_id,
    'updatedCount', updated_count,
    'lateCount', late_count,
    'openExceptionCount', open_count
  );
end;
$$;

revoke all on function public.record_assignment_statuses_batch(uuid, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.record_assignment_statuses_batch(uuid, text, jsonb)
  to authenticated;

commit;
