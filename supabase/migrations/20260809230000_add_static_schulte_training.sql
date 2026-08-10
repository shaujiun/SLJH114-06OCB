-- 靜態舒爾特專注力訓練：個人紀錄、每日任務與難度進程。

create table if not exists public.schulte_attempts (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  focus_task_id uuid references public.student_focus_tasks(id) on delete set null,
  mode text not null default 'static' check (mode in ('static', 'dynamic', 'shape', 'sentence')),
  grid_size smallint not null check (grid_size between 2 and 10),
  duration_ms integer not null check (duration_ms between 1 and 3600000),
  error_count integer not null default 0 check (error_count between 0 and 9999),
  average_tap_ms integer not null check (average_tap_ms between 0 and 3600000),
  completed_at timestamptz not null default now()
);

create index if not exists schulte_attempts_student_mode_size_idx
  on public.schulte_attempts(student_id, mode, grid_size, completed_at desc);

alter table public.schulte_attempts enable row level security;

drop policy if exists schulte_attempts_self_read on public.schulte_attempts;
create policy schulte_attempts_self_read on public.schulte_attempts
for select to authenticated using (public.is_student_self(student_id));

drop policy if exists schulte_attempts_admin_read on public.schulte_attempts;
create policy schulte_attempts_admin_read on public.schulte_attempts
for select to authenticated using (public.contact_book_is_admin());

insert into public.learning_systems (
  subject_code,
  subject_name,
  description,
  launch_url,
  display_order,
  weekly_minimum,
  weekly_maximum,
  audience_scope,
  is_active
) values (
  'focus_training',
  '專注力訓練',
  '用舒爾特學習法練習視覺搜尋、注意力與穩定度，不受科目分組限制。',
  'https://shaujiun.github.io/SLJH-learning-hub/?game=schulte-static',
  5,
  3,
  3,
  'common',
  true
)
on conflict (subject_code) do update set
  subject_name = excluded.subject_name,
  description = excluded.description,
  launch_url = excluded.launch_url,
  display_order = excluded.display_order,
  weekly_minimum = excluded.weekly_minimum,
  weekly_maximum = excluded.weekly_maximum,
  audience_scope = excluded.audience_scope,
  is_active = excluded.is_active,
  updated_at = now();

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
  'schulte_static_' || level.grid_size,
  level.label || '舒爾特 ' || level.grid_size || '×' || level.grid_size,
  '&size=' || level.grid_size,
  1,
  1,
  100,
  level.display_order,
  true
from public.learning_systems system
cross join (
  values
    (4, '入門', 10),
    (5, '標準', 20),
    (6, '挑戰', 30)
) as level(grid_size, label, display_order)
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

create or replace function public.record_schulte_attempt(
  p_focus_task_id uuid default null,
  p_grid_size integer default 4,
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
  if p_grid_size not in (4, 5, 6) then
    raise exception using errcode = '22023', message = 'invalid_schulte_grid_size';
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
      and lower(task.activity_code_snapshot::text) = 'schulte_static_' || p_grid_size
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
    'static',
    p_grid_size,
    p_duration_ms,
    p_error_count,
    round(p_duration_ms::numeric / (p_grid_size * p_grid_size))::integer
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
    and attempt.mode = 'static'
    and attempt.grid_size = p_grid_size;

  return jsonb_build_object(
    'attemptId', inserted_attempt.id,
    'taskCompleted', selected_task.id is not null,
    'personalBestMs', personal_best_ms,
    'completedCount', (
      select count(*)
      from public.schulte_attempts attempt
      where attempt.student_id = current_student_id
        and attempt.mode = 'static'
    )
  );
end;
$$;

revoke all on function public.record_schulte_attempt(uuid, integer, integer, integer) from public;
grant execute on function public.record_schulte_attempt(uuid, integer, integer, integer) to authenticated;

create or replace function public.ensure_student_focus_week(
  p_reference_date date default current_date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_student_id uuid;
  selected_week_start date := date_trunc('week', p_reference_date::timestamp)::date;
  system_row record;
  activity_row record;
  weekly_target integer;
  task_index integer;
  activity_count integer;
  day_offset integer;
  daily_count integer;
  same_system_daily_count integer;
  attempts integer;
  selected_group text;
  selected_level text;
  task_level text;
  beginner_task_count integer;
  schulte_completed_count integer;
  schulte_activity_code text;
begin
  select student.id
  into current_student_id
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

  perform pg_advisory_xact_lock(hashtext(current_student_id::text || selected_week_start::text));

  update public.student_focus_tasks
  set status = 'expired', updated_at = now()
  where student_id = current_student_id
    and week_start < selected_week_start
    and status = 'pending';

  if exists (
    select 1 from public.student_focus_week_states state
    where state.student_id = current_student_id
      and state.week_start = selected_week_start
  ) then
    return;
  end if;

  insert into public.student_focus_week_states(student_id, week_start)
  values (current_student_id, selected_week_start);

  for system_row in
    select system.*
    from public.learning_systems system
    where system.is_active
      and public.learning_system_matches_student(
        system.audience_scope,
        current_student_id,
        p_reference_date
      )
      and exists (
        select 1 from public.learning_activities activity
        where activity.learning_system_id = system.id
          and activity.is_active
      )
    order by system.display_order, system.subject_name
  loop
    weekly_target := system_row.weekly_minimum
      + floor(random() * (system_row.weekly_maximum - system_row.weekly_minimum + 1))::integer;
    selected_group := case system_row.audience_scope
      when 'math_a' then 'A'
      when 'math_b' then 'B'
      when 'english_a' then 'A'
      when 'english_b' then 'B'
      else public.resolve_student_learning_group(
        current_student_id,
        system_row.subject_code::text,
        p_reference_date
      )
    end;
    selected_level := null;
    schulte_activity_code := null;

    if lower(system_row.subject_code::text) = 'science' then
      insert into public.student_learning_levels (
        student_id,
        learning_system_id,
        current_level,
        consecutive_passes
      ) values (
        current_student_id,
        system_row.id,
        'beginner',
        0
      ) on conflict (student_id, learning_system_id) do nothing;

      select level.current_level into selected_level
      from public.student_learning_levels level
      where level.student_id = current_student_id
        and level.learning_system_id = system_row.id;
    elsif lower(system_row.subject_code::text) = 'focus_training' then
      select count(*) into schulte_completed_count
      from public.schulte_attempts attempt
      where attempt.student_id = current_student_id
        and attempt.mode = 'static';

      schulte_activity_code := case
        when schulte_completed_count < 5 then 'schulte_static_4'
        when schulte_completed_count < 10 then 'schulte_static_5'
        else 'schulte_static_6'
      end;
      selected_group := 'COMMON';
    end if;

    for task_index in 1..weekly_target loop
      task_level := selected_level;

      if lower(system_row.subject_code::text) = 'science'
        and selected_level = 'beginner' then
        select count(*) into beginner_task_count
        from public.student_focus_tasks task
        where task.student_id = current_student_id
          and lower(task.subject_code_snapshot::text) = 'science'
          and lower(task.activity_code_snapshot::text) like 'periodic_beginner_%';

        if beginner_task_count >= 5 then
          selected_level := 'advanced';
          task_level := 'advanced';

          update public.student_learning_levels level
          set current_level = 'advanced',
              consecutive_passes = 0,
              updated_at = now()
          where level.student_id = current_student_id
            and level.learning_system_id = system_row.id
            and level.current_level = 'beginner';
        end if;
      end if;

      select count(*) into activity_count
      from public.learning_activities activity
      where activity.learning_system_id = system_row.id
        and activity.is_active
        and (
          (schulte_activity_code is not null and lower(activity.activity_code::text) = schulte_activity_code)
          or (
            schulte_activity_code is null
            and (task_level is null or lower(activity.activity_code::text) like 'periodic_' || task_level || '_%')
          )
        );

      if activity_count = 0 then
        continue;
      end if;

      select activity.*
      into activity_row
      from public.learning_activities activity
      where activity.learning_system_id = system_row.id
        and activity.is_active
        and (
          (schulte_activity_code is not null and lower(activity.activity_code::text) = schulte_activity_code)
          or (
            schulte_activity_code is null
            and (task_level is null or lower(activity.activity_code::text) like 'periodic_' || task_level || '_%')
          )
        )
      order by
        mod(activity.display_order + task_index - 2 + floor(random() * activity_count)::integer, activity_count),
        activity.display_order
      limit 1;

      attempts := 0;
      loop
        day_offset := floor(random() * 5)::integer;
        select count(*) into daily_count
        from public.student_focus_tasks task
        where task.student_id = current_student_id
          and task.week_start = selected_week_start
          and task.assigned_date = selected_week_start + day_offset;

        select count(*) into same_system_daily_count
        from public.student_focus_tasks task
        where task.student_id = current_student_id
          and task.week_start = selected_week_start
          and task.assigned_date = selected_week_start + day_offset
          and lower(task.subject_code_snapshot::text) = lower(system_row.subject_code::text);

        exit when daily_count < 4
          and (lower(system_row.subject_code::text) <> 'focus_training' or same_system_daily_count = 0);
        attempts := attempts + 1;
        exit when attempts >= 20;
      end loop;

      if daily_count >= 4
        or (lower(system_row.subject_code::text) = 'focus_training' and same_system_daily_count > 0) then
        select day_number
        into day_offset
        from generate_series(0, 4) as day_number
        where (
          lower(system_row.subject_code::text) <> 'focus_training'
          or not exists (
            select 1
            from public.student_focus_tasks task
            where task.student_id = current_student_id
              and task.week_start = selected_week_start
              and task.assigned_date = selected_week_start + day_number
              and lower(task.subject_code_snapshot::text) = 'focus_training'
          )
        )
        order by (
          select count(*)
          from public.student_focus_tasks task
          where task.student_id = current_student_id
            and task.week_start = selected_week_start
            and task.assigned_date = selected_week_start + day_number
        ), random()
        limit 1;
      end if;

      insert into public.student_focus_tasks (
        student_id,
        week_start,
        assigned_date,
        learning_activity_id,
        subject_code_snapshot,
        subject_name_snapshot,
        activity_code_snapshot,
        activity_name_snapshot,
        launch_url_snapshot,
        group_code_snapshot,
        question_count,
        target_score,
        slot_number
      ) values (
        current_student_id,
        selected_week_start,
        selected_week_start + day_offset,
        activity_row.id,
        system_row.subject_code,
        system_row.subject_name,
        activity_row.activity_code,
        activity_row.activity_name,
        system_row.launch_url || activity_row.launch_path,
        selected_group,
        case when selected_group = 'A' then activity_row.question_count_a else activity_row.question_count_b end,
        activity_row.target_score,
        task_index
      );
    end loop;
  end loop;
end;
$$;

revoke all on function public.ensure_student_focus_week(date) from public;
grant execute on function public.ensure_student_focus_week(date) to authenticated;
