-- 自然科元素週期表遊戲、個人熟練等級與每日任務進階。

create table if not exists public.student_learning_levels (
  student_id uuid not null references public.students(id) on delete cascade,
  learning_system_id uuid not null references public.learning_systems(id) on delete cascade,
  current_level text not null default 'beginner'
    check (current_level in ('beginner', 'advanced', 'challenge')),
  consecutive_passes smallint not null default 0 check (consecutive_passes between 0 and 99),
  updated_at timestamptz not null default now(),
  primary key (student_id, learning_system_id)
);

alter table public.student_learning_levels enable row level security;

drop policy if exists student_learning_levels_self_read on public.student_learning_levels;
create policy student_learning_levels_self_read on public.student_learning_levels
for select to authenticated using (public.is_student_self(student_id));

drop policy if exists student_learning_levels_admin_manage on public.student_learning_levels;
create policy student_learning_levels_admin_manage on public.student_learning_levels
for all to authenticated
using (public.contact_book_is_admin())
with check (public.contact_book_is_admin());

create or replace function public.admin_set_student_learning_level(
  p_student_id uuid,
  p_subject_code text,
  p_level_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_system_id uuid;
  normalized_level text := lower(trim(p_level_code));
begin
  if not public.contact_book_is_admin() then
    raise exception using errcode = '42501', message = 'admin_required';
  end if;

  if normalized_level not in ('beginner', 'advanced', 'challenge') then
    raise exception using errcode = '22023', message = 'invalid_learning_level';
  end if;

  if not exists (
    select 1 from public.students student
    where student.id = p_student_id and student.is_active
  ) then
    raise exception using errcode = 'P0001', message = 'student_not_found';
  end if;

  select system.id into target_system_id
  from public.learning_systems system
  where lower(system.subject_code::text) = lower(trim(p_subject_code))
  limit 1;

  if target_system_id is null then
    raise exception using errcode = 'P0001', message = 'learning_system_not_found';
  end if;

  insert into public.student_learning_levels (
    student_id,
    learning_system_id,
    current_level,
    consecutive_passes,
    updated_at
  ) values (
    p_student_id,
    target_system_id,
    normalized_level,
    0,
    now()
  )
  on conflict (student_id, learning_system_id) do update set
    current_level = excluded.current_level,
    consecutive_passes = 0,
    updated_at = now();

  return jsonb_build_object(
    'studentId', p_student_id,
    'subjectCode', lower(trim(p_subject_code)),
    'learningLevel', normalized_level,
    'consecutivePasses', 0
  );
end;
$$;

revoke all on function public.admin_set_student_learning_level(uuid, text, text) from public;
grant execute on function public.admin_set_student_learning_level(uuid, text, text) to authenticated;

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
  'science',
  '自然科',
  '用元素名稱、符號與週期表定位，逐步熟悉指定元素。',
  'https://shaujiun.github.io/SLJH-learning-hub/?game=periodic-table',
  20,
  1,
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
  'periodic_' || level.code || '_' || mode.code,
  level.label || '・' || mode.label,
  '&level=' || level.code || '&mode=' || mode.code,
  level.question_count,
  level.question_count,
  80,
  level.display_order + mode.display_order,
  true
from public.learning_systems system
cross join (
  values
    ('beginner', '入門', 10, 0),
    ('advanced', '進階', 20, 100),
    ('challenge', '挑戰', 20, 200)
) as level(code, label, question_count, display_order)
cross join (
  values
    ('name_symbol', '中文名稱選符號', 10),
    ('symbol_name', '元素符號選名稱', 20),
    ('locate', '週期表定位', 30),
    ('mixed', '混合挑戰', 40)
) as mode(code, label, display_order)
where lower(system.subject_code::text) = 'science'
on conflict (learning_system_id, activity_code) do update set
  activity_name = excluded.activity_name,
  launch_path = excluded.launch_path,
  question_count_a = excluded.question_count_a,
  question_count_b = excluded.question_count_b,
  target_score = excluded.target_score,
  display_order = excluded.display_order,
  is_active = excluded.is_active,
  updated_at = now();

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
  attempts integer;
  selected_group text;
  selected_level text;
  task_level text;
  beginner_task_count integer;
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
    end if;

    for task_index in 1..weekly_target loop
      task_level := selected_level;

      -- 前 5 個已安排的元素週期表任務維持入門；第 6 個起即使尚未
      -- 連續達標，也改為進階。已產生的入門任務不會被回溯修改。
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
          task_level is null
          or lower(activity.activity_code::text) like 'periodic_' || task_level || '_%'
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
          task_level is null
          or lower(activity.activity_code::text) like 'periodic_' || task_level || '_%'
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
        exit when daily_count < 4;
        attempts := attempts + 1;
        exit when attempts >= 20;
      end loop;

      if daily_count >= 4 then
        select day_number
        into day_offset
        from generate_series(0, 4) as day_number
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

create or replace function public.record_focus_task_attempt(
  p_focus_task_id uuid,
  p_score integer,
  p_correct_count integer default null,
  p_question_count integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_student_id uuid;
  selected_task public.student_focus_tasks%rowtype;
  passed boolean;
  science_system_id uuid;
  progress_level text;
  progress_passes integer;
  required_passes integer;
  leveled_up boolean := false;
  attempt_level text;
begin
  if p_score < 0 or p_score > 100 then
    raise exception using errcode = '22023', message = 'invalid_focus_task_score';
  end if;

  select student.id into current_student_id
  from public.students student
  where student.profile_id = auth.uid()
    and student.is_active
  limit 1;

  select task.* into selected_task
  from public.student_focus_tasks task
  where task.id = p_focus_task_id
    and task.student_id = current_student_id
  for update;

  if selected_task.id is null then
    raise exception using errcode = 'P0001', message = 'focus_task_not_found';
  end if;

  insert into public.focus_task_attempts (
    focus_task_id,
    student_id,
    score,
    correct_count,
    question_count
  ) values (
    selected_task.id,
    current_student_id,
    p_score,
    p_correct_count,
    p_question_count
  );

  passed := p_score >= selected_task.target_score;

  if lower(selected_task.subject_code_snapshot::text) = 'science'
    and selected_task.status <> 'completed' then
    select system.id into science_system_id
    from public.learning_systems system
    where lower(system.subject_code::text) = 'science'
    limit 1;

    insert into public.student_learning_levels (
      student_id,
      learning_system_id,
      current_level,
      consecutive_passes
    ) values (
      current_student_id,
      science_system_id,
      'beginner',
      0
    ) on conflict (student_id, learning_system_id) do nothing;

    select level.current_level, level.consecutive_passes
    into progress_level, progress_passes
    from public.student_learning_levels level
    where level.student_id = current_student_id
      and level.learning_system_id = science_system_id
    for update;

    attempt_level := split_part(lower(selected_task.activity_code_snapshot::text), '_', 2);

    -- 已升級後仍可完成先前產生的舊入門任務，但舊難度作答不會
    -- 累加或重設目前進階等級的連續達標紀錄。
    if attempt_level = progress_level then
      if p_score < 80 then
        progress_passes := 0;
      elsif progress_level = 'beginner' then
        progress_passes := progress_passes + 1;
        if progress_passes >= 3 then
          progress_level := 'advanced';
          progress_passes := 0;
          leveled_up := true;
        end if;
      elsif progress_level = 'advanced' then
        progress_passes := progress_passes + 1;
        if progress_passes >= 5 then
          progress_level := 'challenge';
          progress_passes := 0;
          leveled_up := true;
        end if;
      else
        progress_passes := 0;
      end if;
    end if;

    update public.student_learning_levels level
    set current_level = progress_level,
        consecutive_passes = progress_passes,
        updated_at = now()
    where level.student_id = current_student_id
      and level.learning_system_id = science_system_id;
  end if;

  update public.student_focus_tasks task
  set best_score = greatest(coalesce(task.best_score, 0), p_score),
      status = case when passed then 'completed' else task.status end,
      completed_at = case when passed then coalesce(task.completed_at, now()) else task.completed_at end,
      updated_at = now()
  where task.id = selected_task.id;

  required_passes := case progress_level
    when 'beginner' then 3
    when 'advanced' then 5
    else null
  end;

  return jsonb_build_object(
    'taskId', selected_task.id,
    'passed', passed,
    'score', p_score,
    'targetScore', selected_task.target_score,
    'learningLevel', progress_level,
    'consecutivePasses', progress_passes,
    'requiredPasses', required_passes,
    'leveledUp', leveled_up
  );
end;
$$;

revoke all on function public.ensure_student_focus_week(date) from public;
revoke all on function public.record_focus_task_attempt(uuid, integer, integer, integer) from public;
grant execute on function public.ensure_student_focus_week(date) to authenticated;
grant execute on function public.record_focus_task_attempt(uuid, integer, integer, integer) to authenticated;
