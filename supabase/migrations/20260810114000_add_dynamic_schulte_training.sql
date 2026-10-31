-- 動態舒爾特第二階段：1～20、1～35、1～50 個人紀錄與未來任務入口。
-- 本遷移不改動目前每週自動排定的靜態舒爾特任務。

alter table public.schulte_attempts
  drop constraint if exists schulte_attempts_grid_size_check;

alter table public.schulte_attempts
  add constraint schulte_attempts_grid_size_check check (
    (mode = 'static' and grid_size in (4, 5, 6))
    or (mode = 'dynamic' and grid_size in (20, 35, 50))
    or (mode in ('shape', 'sentence') and grid_size between 2 and 100)
  );

update public.learning_systems
set launch_url = 'https://shaujiun.github.io/SLJH-learning-hub/?',
    updated_at = now()
where lower(subject_code::text) = 'focus_training';

update public.learning_activities activity
set launch_path = 'game=schulte-static&size=' || split_part(activity.activity_code::text, '_', 3),
    updated_at = now()
from public.learning_systems system
where activity.learning_system_id = system.id
  and lower(system.subject_code::text) = 'focus_training'
  and lower(activity.activity_code::text) like 'schulte_static_%';

insert into public.learning_activities (
  learning_system_id,
  activity_code,
  activity_name,
  launch_path,
  question_count_a,
  question_count_b,
  target_score,
  display_order,
  is_active
)
select
  system.id,
  'schulte_dynamic_' || level.item_count,
  level.label || '動態舒爾特 1～' || level.item_count,
  'game=schulte-dynamic&count=' || level.item_count,
  1,
  1,
  100,
  level.display_order,
  true
from public.learning_systems system
cross join (
  values
    (20, '入門', 40),
    (35, '進階', 50),
    (50, '挑戰', 60)
) as level(item_count, label, display_order)
where lower(system.subject_code::text) = 'focus_training'
on conflict (learning_system_id, activity_code) do update set
  activity_name = excluded.activity_name,
  launch_path = excluded.launch_path,
  question_count_a = excluded.question_count_a,
  question_count_b = excluded.question_count_b,
  target_score = excluded.target_score,
  display_order = excluded.display_order,
  is_active = excluded.is_active,
  updated_at = now();

create or replace function public.record_dynamic_schulte_attempt(
  p_focus_task_id uuid default null,
  p_item_count integer default 20,
  p_duration_ms integer default 1,
  p_error_count integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_student_id uuid;
  selected_task public.student_focus_tasks%rowtype;
  inserted_attempt public.schulte_attempts%rowtype;
  personal_best_ms integer;
begin
  if p_item_count not in (20, 35, 50) then
    raise exception using errcode = '22023', message = 'invalid_dynamic_schulte_item_count';
  end if;
  if p_duration_ms < 1 or p_duration_ms > 3600000 then
    raise exception using errcode = '22023', message = 'invalid_schulte_duration';
  end if;
  if p_error_count < 0 or p_error_count > 9999 then
    raise exception using errcode = '22023', message = 'invalid_schulte_error_count';
  end if;

  select student.id into current_student_id
  from public.students student
  join public.contact_book_profiles profile on profile.id = student.profile_id
  where student.profile_id = auth.uid()
    and student.is_active
    and profile.is_active
    and profile.approval_status = 'approved'
  limit 1;

  if current_student_id is null then
    raise exception using errcode = 'P0001', message = 'student_profile_not_found';
  end if;

  if p_focus_task_id is not null then
    select task.* into selected_task
    from public.student_focus_tasks task
    where task.id = p_focus_task_id
      and task.student_id = current_student_id
      and lower(task.subject_code_snapshot::text) = 'focus_training'
      and lower(task.activity_code_snapshot::text) = 'schulte_dynamic_' || p_item_count
    for update;

    if selected_task.id is null then
      raise exception using errcode = 'P0001', message = 'schulte_focus_task_not_found';
    end if;
  end if;

  insert into public.schulte_attempts (
    student_id,
    focus_task_id,
    mode,
    grid_size,
    duration_ms,
    error_count,
    average_tap_ms
  ) values (
    current_student_id,
    p_focus_task_id,
    'dynamic',
    p_item_count,
    p_duration_ms,
    p_error_count,
    round(p_duration_ms::numeric / p_item_count)::integer
  ) returning * into inserted_attempt;

  if selected_task.id is not null then
    update public.student_focus_tasks task
    set best_score = 100,
        status = 'completed',
        completed_at = coalesce(task.completed_at, now()),
        updated_at = now()
    where task.id = selected_task.id;
  end if;

  select min(attempt.duration_ms) into personal_best_ms
  from public.schulte_attempts attempt
  where attempt.student_id = current_student_id
    and attempt.mode = 'dynamic'
    and attempt.grid_size = p_item_count;

  return jsonb_build_object(
    'attemptId', inserted_attempt.id,
    'taskCompleted', selected_task.id is not null,
    'personalBestMs', personal_best_ms,
    'completedCount', (
      select count(*)
      from public.schulte_attempts attempt
      where attempt.student_id = current_student_id
        and attempt.mode = 'dynamic'
    )
  );
end;
$$;

revoke all on function public.record_dynamic_schulte_attempt(uuid, integer, integer, integer) from public;
grant execute on function public.record_dynamic_schulte_attempt(uuid, integer, integer, integer) to authenticated;
