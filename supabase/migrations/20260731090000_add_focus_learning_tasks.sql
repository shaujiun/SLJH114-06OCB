-- 各科學習入口與每日專注任務。
-- 本 migration 只新增資料表、函式與 RLS，不修改既有聯絡簿或英文單字資料。

create table if not exists public.learning_systems (
  id uuid primary key default gen_random_uuid(),
  subject_code citext not null unique,
  subject_name text not null,
  description text not null default '',
  launch_url text not null,
  display_order integer not null default 0,
  weekly_minimum smallint not null default 1 check (weekly_minimum between 1 and 3),
  weekly_maximum smallint not null default 3 check (weekly_maximum between 1 and 3),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint learning_system_weekly_range_valid check (weekly_maximum >= weekly_minimum)
);

create table if not exists public.learning_activities (
  id uuid primary key default gen_random_uuid(),
  learning_system_id uuid not null references public.learning_systems(id) on delete cascade,
  activity_code citext not null,
  activity_name text not null,
  launch_path text not null default '',
  question_count_a smallint not null default 20 check (question_count_a between 1 and 50),
  question_count_b smallint not null default 10 check (question_count_b between 1 and 50),
  target_score smallint not null default 80 check (target_score between 0 and 100),
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint learning_activity_code_unique unique (learning_system_id, activity_code)
);

create table if not exists public.student_focus_week_states (
  student_id uuid not null references public.students(id) on delete cascade,
  week_start date not null,
  weekend_prepared_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (student_id, week_start)
);

create table if not exists public.student_focus_tasks (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  week_start date not null,
  assigned_date date not null,
  learning_activity_id uuid not null references public.learning_activities(id) on delete restrict,
  subject_code_snapshot citext not null,
  subject_name_snapshot text not null,
  activity_code_snapshot citext not null,
  activity_name_snapshot text not null,
  launch_url_snapshot text not null,
  group_code_snapshot citext not null default 'B',
  question_count smallint not null check (question_count between 1 and 50),
  target_score smallint not null check (target_score between 0 and 100),
  slot_number smallint not null check (slot_number between 1 and 10),
  status text not null default 'pending' check (status in ('pending', 'completed', 'expired')),
  best_score smallint check (best_score between 0 and 100),
  carry_to_weekend boolean,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint focus_task_week_subject_slot_unique unique (
    student_id,
    week_start,
    subject_code_snapshot,
    slot_number
  )
);

create table if not exists public.focus_task_attempts (
  id uuid primary key default gen_random_uuid(),
  focus_task_id uuid not null references public.student_focus_tasks(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  score smallint not null check (score between 0 and 100),
  correct_count smallint check (correct_count >= 0),
  question_count smallint check (question_count > 0),
  attempted_at timestamptz not null default now()
);

create index if not exists focus_tasks_student_date_idx
  on public.student_focus_tasks(student_id, assigned_date, status);

create index if not exists focus_attempts_task_idx
  on public.focus_task_attempts(focus_task_id, attempted_at desc);

alter table public.learning_systems enable row level security;
alter table public.learning_activities enable row level security;
alter table public.student_focus_week_states enable row level security;
alter table public.student_focus_tasks enable row level security;
alter table public.focus_task_attempts enable row level security;

create policy learning_systems_authenticated_read on public.learning_systems
for select to authenticated using (true);

create policy learning_systems_admin_manage on public.learning_systems
for all to authenticated
using (public.contact_book_is_admin())
with check (public.contact_book_is_admin());

create policy learning_activities_authenticated_read on public.learning_activities
for select to authenticated using (true);

create policy learning_activities_admin_manage on public.learning_activities
for all to authenticated
using (public.contact_book_is_admin())
with check (public.contact_book_is_admin());

create policy focus_week_state_self_read on public.student_focus_week_states
for select to authenticated using (public.is_student_self(student_id));

create policy focus_week_state_admin_read on public.student_focus_week_states
for select to authenticated using (
  exists (
    select 1 from public.students student
    where student.id = student_id
      and public.can_manage_class(student.class_id)
  )
);

create policy focus_tasks_self_read on public.student_focus_tasks
for select to authenticated using (public.is_student_self(student_id));

create policy focus_tasks_staff_read on public.student_focus_tasks
for select to authenticated using (
  exists (
    select 1 from public.students student
    where student.id = student_id
      and public.can_view_class_roster(student.class_id)
  )
);

create policy focus_attempts_self_read on public.focus_task_attempts
for select to authenticated using (public.is_student_self(student_id));

create policy focus_attempts_staff_read on public.focus_task_attempts
for select to authenticated using (
  exists (
    select 1 from public.students student
    where student.id = student_id
      and public.can_view_class_roster(student.class_id)
  )
);

create or replace function public.resolve_student_learning_group(
  p_student_id uuid,
  p_subject_code text,
  p_reference_date date default current_date
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  resolved_group text;
begin
  if lower(trim(p_subject_code)) <> 'english' then
    return 'COMMON';
  end if;

  select upper(grouping.group_code::text)
  into resolved_group
  from public.student_subject_groups grouping
  join public.class_subjects class_subject on class_subject.id = grouping.class_subject_id
  join public.subjects subject on subject.id = class_subject.subject_id
  where grouping.student_id = p_student_id
    and lower(subject.code::text) = lower(trim(p_subject_code))
  order by
    case
      when grouping.effective_from <= p_reference_date
        and (grouping.effective_to is null or grouping.effective_to >= p_reference_date) then 0
      when grouping.effective_from > p_reference_date then 1
      else 2
    end,
    case when grouping.effective_from > p_reference_date then grouping.effective_from end asc,
    grouping.effective_from desc
  limit 1;

  return coalesce(resolved_group, 'B');
end;
$$;

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
      and exists (
        select 1 from public.learning_activities activity
        where activity.learning_system_id = system.id
          and activity.is_active
      )
    order by system.display_order, system.subject_name
  loop
    weekly_target := system_row.weekly_minimum
      + floor(random() * (system_row.weekly_maximum - system_row.weekly_minimum + 1))::integer;
    selected_group := public.resolve_student_learning_group(
      current_student_id,
      system_row.subject_code::text,
      p_reference_date
    );

    select count(*) into activity_count
    from public.learning_activities activity
    where activity.learning_system_id = system_row.id
      and activity.is_active;

    for task_index in 1..weekly_target loop
      select activity.*
      into activity_row
      from public.learning_activities activity
      where activity.learning_system_id = system_row.id
        and activity.is_active
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
  day_offset integer := p_reference_date - selected_week_start;
  pending_count integer;
  carry_count integer;
begin
  perform public.ensure_student_focus_week(p_reference_date);

  select student.id into current_student_id
  from public.students student
  where student.profile_id = auth.uid()
    and student.is_active
  limit 1;

  if day_offset between 5 and 6
    and not exists (
      select 1
      from public.student_focus_week_states state
      where state.student_id = current_student_id
        and state.week_start = selected_week_start
        and state.weekend_prepared_at is not null
    ) then
    select count(*) into pending_count
    from public.student_focus_tasks task
    where task.student_id = current_student_id
      and task.week_start = selected_week_start
      and task.status = 'pending';

    carry_count := case
      when pending_count = 0 then 0
      else greatest(1, round(pending_count * 0.7)::integer)
    end;

    update public.student_focus_tasks task
    set carry_to_weekend = false,
        updated_at = now()
    where task.student_id = current_student_id
      and task.week_start = selected_week_start
      and task.status = 'pending';

    if carry_count > 0 then
      with selected_tasks as (
        select task.id
        from public.student_focus_tasks task
        where task.student_id = current_student_id
          and task.week_start = selected_week_start
          and task.status = 'pending'
        order by random()
        limit carry_count
      )
      update public.student_focus_tasks task
      set carry_to_weekend = true,
          updated_at = now()
      from selected_tasks
      where task.id = selected_tasks.id;
    end if;

    update public.student_focus_week_states state
    set weekend_prepared_at = now()
    where state.student_id = current_student_id
      and state.week_start = selected_week_start;
  end if;

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
    coalesce(task.carry_to_weekend, false)
  from public.student_focus_tasks task
  where task.student_id = current_student_id
    and task.week_start = selected_week_start
    and (
      (day_offset between 0 and 4 and task.assigned_date = p_reference_date)
      or (day_offset between 5 and 6 and task.status = 'pending' and task.carry_to_weekend)
    )
  order by task.status = 'completed', task.assigned_date, task.created_at;
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
    'targetScore', selected_task.target_score
  );
end;
$$;

revoke all on function public.resolve_student_learning_group(uuid, text, date) from public;
revoke all on function public.ensure_student_focus_week(date) from public;
revoke all on function public.prepare_student_focus_tasks(date) from public;
revoke all on function public.record_focus_task_attempt(uuid, integer, integer, integer) from public;

grant execute on function public.resolve_student_learning_group(uuid, text, date) to authenticated;
grant execute on function public.ensure_student_focus_week(date) to authenticated;
grant execute on function public.prepare_student_focus_tasks(date) to authenticated;
grant execute on function public.record_focus_task_attempt(uuid, integer, integer, integer) to authenticated;

insert into public.learning_systems (
  subject_code,
  subject_name,
  description,
  launch_url,
  display_order,
  weekly_minimum,
  weekly_maximum,
  is_active
) values (
  'english',
  '英語',
  '從單字、句子到口說，依英語分組提供合適的練習。',
  'https://shaujiun.github.io/englishvocabking/',
  10,
  1,
  3,
  true
)
on conflict (subject_code) do update set
  subject_name = excluded.subject_name,
  description = excluded.description,
  launch_url = excluded.launch_url,
  display_order = excluded.display_order,
  weekly_minimum = excluded.weekly_minimum,
  weekly_maximum = excluded.weekly_maximum,
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
  activity.activity_code,
  activity.activity_name,
  activity.launch_path,
  20,
  10,
  activity.target_score,
  activity.display_order,
  true
from public.learning_systems system
cross join (
  values
    ('listening', '聽音辨字王', '?focusActivity=listening', 80, 10),
    ('spelling', '字母拼拼樂', '?focusActivity=spelling', 80, 20),
    ('sentence', '句子重組', '?focusActivity=sentence', 80, 30),
    ('matching', '翻牌連連看', '?focusActivity=matching', 80, 40),
    ('pronunciation', 'AI 口說發音王', '?focusActivity=pronunciation', 70, 50)
) as activity(activity_code, activity_name, launch_path, target_score, display_order)
where system.subject_code = 'english'
on conflict (learning_system_id, activity_code) do update set
  activity_name = excluded.activity_name,
  launch_path = excluded.launch_path,
  question_count_a = excluded.question_count_a,
  question_count_b = excluded.question_count_b,
  target_score = excluded.target_score,
  display_order = excluded.display_order,
  is_active = excluded.is_active,
  updated_at = now();
