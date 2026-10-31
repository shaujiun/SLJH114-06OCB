-- 本週截至今天的所有未完成任務都保留在學生任務頁，不再只抽取約七成供週末補做。
create or replace function public.prepare_student_focus_tasks(
  p_reference_date date default current_date
)
returns table (
  id uuid,
  assigned_date date,
  subject_code text,
  subject_name text,
  activity_code text,
  activity_name text,
  launch_url text,
  group_code text,
  question_count smallint,
  target_score smallint,
  status text,
  best_score smallint,
  completed_at timestamptz,
  is_weekend_carryover boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  current_student_id uuid;
  selected_week_start date := date_trunc('week', p_reference_date::timestamp)::date;
begin
  perform public.ensure_student_focus_week(p_reference_date);

  select student.id into current_student_id
  from public.students student
  where student.profile_id = auth.uid()
    and student.is_active
  limit 1;

  return query
  select
    task.id,
    task.assigned_date,
    task.subject_code_snapshot::text,
    task.subject_name_snapshot,
    task.activity_code_snapshot::text,
    task.activity_name_snapshot,
    task.launch_url_snapshot,
    task.group_code_snapshot::text,
    task.question_count,
    task.target_score,
    task.status,
    task.best_score,
    task.completed_at,
    (task.status = 'pending' and task.assigned_date < p_reference_date)
  from public.student_focus_tasks task
  where task.student_id = current_student_id
    and task.week_start = selected_week_start
    and task.assigned_date <= p_reference_date
    and (task.status = 'pending' or task.assigned_date = p_reference_date)
  order by task.status = 'completed', task.assigned_date, task.created_at;
end;
$$;

revoke all on function public.prepare_student_focus_tasks(date) from public;
grant execute on function public.prepare_student_focus_tasks(date) to authenticated;
