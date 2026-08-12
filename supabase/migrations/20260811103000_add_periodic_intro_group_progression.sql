-- 元素週期表新增逐族入門，原 beginner 等級改名為基礎。

alter table public.student_learning_levels
  drop constraint if exists student_learning_levels_current_level_check;
alter table public.student_learning_levels
  alter column current_level set default 'intro';
alter table public.student_learning_levels
  add constraint student_learning_levels_current_level_check
  check (current_level in ('intro', 'beginner', 'advanced', 'challenge'));
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

  if normalized_level not in ('intro', 'beginner', 'advanced', 'challenge') then
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
    'consecutivePasses', 0,
    'introGroup', case when normalized_level = 'intro' then 1 else null end
  );
end;
$$;
revoke all on function public.admin_set_student_learning_level(uuid, text, text) from public;
grant execute on function public.admin_set_student_learning_level(uuid, text, text) to authenticated;
-- 原入門活動保留相同代碼，以免破壞既有對戰房間及歷史紀錄，只更名為基礎。
update public.learning_activities activity
set activity_name = replace(activity.activity_name, '入門・', '基礎・'),
    display_order = activity.display_order + 100,
    updated_at = now()
from public.learning_systems system
where activity.learning_system_id = system.id
  and lower(system.subject_code::text) = 'science'
  and lower(activity.activity_code::text) like 'periodic_beginner_%';
update public.learning_activities activity
set display_order = activity.display_order + 100,
    updated_at = now()
from public.learning_systems system
where activity.learning_system_id = system.id
  and lower(system.subject_code::text) = 'science'
  and lower(activity.activity_code::text) like 'periodic_advanced_%';
update public.learning_activities activity
set display_order = activity.display_order + 100,
    updated_at = now()
from public.learning_systems system
where activity.learning_system_id = system.id
  and lower(system.subject_code::text) = 'science'
  and lower(activity.activity_code::text) like 'periodic_challenge_%';
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
  'periodic_intro_' || mode.code,
  '入門・' || mode.label,
  '&level=intro&mode=' || mode.code,
  7,
  7,
  80,
  mode.display_order,
  true
from public.learning_systems system
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
-- 所有目前啟用中的學生一律從新入門的第 1 族開始。
insert into public.student_learning_levels (
  student_id,
  learning_system_id,
  current_level,
  consecutive_passes,
  updated_at
)
select
  student.id,
  system.id,
  'intro',
  0,
  now()
from public.students student
cross join public.learning_systems system
where student.is_active
  and lower(system.subject_code::text) = 'science'
on conflict (student_id, learning_system_id) do update set
  current_level = 'intro',
  consecutive_passes = 0,
  updated_at = now();
-- 本週尚未完成的舊入門任務同步改成新的逐族入門。
update public.student_focus_tasks task
set learning_activity_id = intro_activity.id,
    activity_code_snapshot = intro_activity.activity_code,
    activity_name_snapshot = intro_activity.activity_name,
    launch_url_snapshot = replace(task.launch_url_snapshot, '&level=beginner', '&level=intro'),
    question_count = 7,
    updated_at = now()
from public.learning_activities old_activity
join public.learning_activities intro_activity
  on intro_activity.learning_system_id = old_activity.learning_system_id
 and lower(intro_activity.activity_code::text) = replace(lower(old_activity.activity_code::text), 'periodic_beginner_', 'periodic_intro_')
where task.learning_activity_id = old_activity.id
  and lower(task.subject_code_snapshot::text) = 'science'
  and lower(task.activity_code_snapshot::text) like 'periodic_beginner_%'
  and task.status = 'pending';
-- 未來新增學生時，預先建立自然科新入門進度，避免舊函式的 beginner 預設值介入。
create or replace function public.initialize_student_science_intro_level()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.student_learning_levels (
    student_id,
    learning_system_id,
    current_level,
    consecutive_passes
  )
  select new.id, system.id, 'intro', 0
  from public.learning_systems system
  where lower(system.subject_code::text) = 'science'
  on conflict (student_id, learning_system_id) do nothing;
  return new;
end;
$$;
drop trigger if exists students_initialize_science_intro_level on public.students;
create trigger students_initialize_science_intro_level
after insert on public.students
for each row execute function public.initialize_student_science_intro_level();
create or replace function public.record_periodic_intro_attempt(
  p_score integer,
  p_intro_group integer,
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
  science_system_id uuid;
  progress_level text;
  completed_groups integer;
  expected_group integer;
  next_group integer;
  leveled_up boolean := false;
begin
  if p_score < 0 or p_score > 100 then
    raise exception using errcode = '22023', message = 'invalid_periodic_score';
  end if;

  select student.id into current_student_id
  from public.students student
  where student.profile_id = auth.uid()
    and student.is_active
  limit 1;

  if current_student_id is null then
    raise exception using errcode = 'P0001', message = 'student_profile_not_found';
  end if;

  select system.id into science_system_id
  from public.learning_systems system
  where lower(system.subject_code::text) = 'science'
  limit 1;

  insert into public.student_learning_levels (
    student_id, learning_system_id, current_level, consecutive_passes
  ) values (
    current_student_id, science_system_id, 'intro', 0
  ) on conflict (student_id, learning_system_id) do nothing;

  select level.current_level, level.consecutive_passes
  into progress_level, completed_groups
  from public.student_learning_levels level
  where level.student_id = current_student_id
    and level.learning_system_id = science_system_id
  for update;

  expected_group := (array[1, 2, 13, 14, 15, 16, 17, 18])[least(completed_groups, 7) + 1];

  if progress_level = 'intro'
    and p_intro_group = expected_group
    and p_score >= 80 then
    completed_groups := completed_groups + 1;
    if completed_groups >= 8 then
      progress_level := 'beginner';
      completed_groups := 0;
      leveled_up := true;
    end if;

    update public.student_learning_levels level
    set current_level = progress_level,
        consecutive_passes = completed_groups,
        updated_at = now()
    where level.student_id = current_student_id
      and level.learning_system_id = science_system_id;
  end if;

  next_group := case when progress_level = 'intro'
    then (array[1, 2, 13, 14, 15, 16, 17, 18])[least(completed_groups, 7) + 1]
    else null
  end;

  return jsonb_build_object(
    'passed', p_score >= 80,
    'score', p_score,
    'learningLevel', progress_level,
    'consecutivePasses', completed_groups,
    'requiredPasses', case when progress_level = 'intro' then 8 when progress_level = 'beginner' then 3 else null end,
    'introGroup', next_group,
    'leveledUp', leveled_up
  );
end;
$$;
revoke all on function public.record_periodic_intro_attempt(integer, integer, integer, integer) from public;
grant execute on function public.record_periodic_intro_attempt(integer, integer, integer, integer) to authenticated;
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
  intro_group integer;
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
    focus_task_id, student_id, score, correct_count, question_count
  ) values (
    selected_task.id, current_student_id, p_score, p_correct_count, p_question_count
  );

  passed := p_score >= selected_task.target_score;

  if lower(selected_task.subject_code_snapshot::text) = 'science'
    and selected_task.status <> 'completed' then
    select system.id into science_system_id
    from public.learning_systems system
    where lower(system.subject_code::text) = 'science'
    limit 1;

    insert into public.student_learning_levels (
      student_id, learning_system_id, current_level, consecutive_passes
    ) values (
      current_student_id, science_system_id, 'intro', 0
    ) on conflict (student_id, learning_system_id) do nothing;

    select level.current_level, level.consecutive_passes
    into progress_level, progress_passes
    from public.student_learning_levels level
    where level.student_id = current_student_id
      and level.learning_system_id = science_system_id
    for update;

    attempt_level := split_part(lower(selected_task.activity_code_snapshot::text), '_', 2);

    if attempt_level = progress_level then
      if progress_level = 'intro' then
        if p_score >= 80 then
          progress_passes := progress_passes + 1;
          if progress_passes >= 8 then
            progress_level := 'beginner';
            progress_passes := 0;
            leveled_up := true;
          end if;
        end if;
      elsif p_score < 80 then
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

  required_passes := case progress_level
    when 'intro' then 8
    when 'beginner' then 3
    when 'advanced' then 5
    else null
  end;
  intro_group := case when progress_level = 'intro'
    then (array[1, 2, 13, 14, 15, 16, 17, 18])[least(progress_passes, 7) + 1]
    else null
  end;

  update public.student_focus_tasks task
  set best_score = greatest(coalesce(task.best_score, 0), p_score),
      status = case when passed then 'completed' else task.status end,
      completed_at = case when passed then coalesce(task.completed_at, now()) else task.completed_at end,
      updated_at = now()
  where task.id = selected_task.id;

  return jsonb_build_object(
    'taskId', selected_task.id,
    'passed', passed,
    'score', p_score,
    'targetScore', selected_task.target_score,
    'learningLevel', progress_level,
    'consecutivePasses', progress_passes,
    'requiredPasses', required_passes,
    'introGroup', intro_group,
    'leveledUp', leveled_up
  );
end;
$$;
revoke all on function public.record_focus_task_attempt(uuid, integer, integer, integer) from public;
grant execute on function public.record_focus_task_attempt(uuid, integer, integer, integer) to authenticated;
