-- 因式交鋒第一階段：帳號學生的單人練習紀錄，以及既有每日任務池中的活動。
-- 每日任務以完成 5 題為條件，target_score = 0，不要求達到特定分數。

create table if not exists public.factor_clash_sessions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  mode text not null check (mode in ('area', 'cross')),
  difficulty text not null check (difficulty in ('basic', 'advanced')),
  question_count smallint not null check (question_count between 1 and 50),
  total_points smallint not null check (total_points between 0 and 150),
  first_try_correct smallint not null default 0 check (first_try_correct >= 0),
  second_try_correct smallint not null default 0 check (second_try_correct >= 0),
  timeout_count smallint not null default 0 check (timeout_count >= 0),
  away_count smallint not null default 0 check (away_count >= 0),
  away_seconds integer not null default 0 check (away_seconds >= 0),
  completed_at timestamptz not null default now()
);

create index if not exists factor_clash_sessions_student_time_idx
  on public.factor_clash_sessions(student_id, completed_at desc);

alter table public.factor_clash_sessions enable row level security;

create policy factor_clash_sessions_self_read on public.factor_clash_sessions
for select to authenticated using (public.is_student_self(student_id));

create policy factor_clash_sessions_self_insert on public.factor_clash_sessions
for insert to authenticated with check (public.is_student_self(student_id));

create policy factor_clash_sessions_staff_read on public.factor_clash_sessions
for select to authenticated using (
  exists (
    select 1 from public.students student
    where student.id = student_id
      and public.can_view_class_roster(student.class_id)
  )
);

grant select, insert on table public.factor_clash_sessions to authenticated;

insert into public.learning_activities (
  learning_system_id, activity_code, activity_name, launch_path,
  question_count_a, question_count_b, target_score, display_order, is_active
)
select
  id, 'factor_clash_solo', '因式交鋒：單人練習', '&game=factor-clash&solo=1',
  5, 5, 0, 12, true
from public.learning_systems
where lower(subject_code::text) = 'math'
on conflict (learning_system_id, activity_code) do update set
  activity_name = excluded.activity_name,
  launch_path = excluded.launch_path,
  question_count_a = excluded.question_count_a,
  question_count_b = excluded.question_count_b,
  target_score = excluded.target_score,
  display_order = excluded.display_order,
  is_active = excluded.is_active,
  updated_at = now();
