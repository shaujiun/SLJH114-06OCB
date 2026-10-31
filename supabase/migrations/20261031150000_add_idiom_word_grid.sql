-- 成語填字圖：教育部《成語典》題庫、可變版面、學生能量、提示與每週任務。

create table if not exists public.idiom_entries (
  id uuid primary key default gen_random_uuid(),
  phrase text not null unique,
  definition text not null default '',
  source_text text not null default '',
  story text not null default '',
  source_url text not null default '',
  illustration_url text not null default '',
  stage text not null default 'junior' check (stage in ('elementary', 'junior', 'senior')),
  license_version text not null default 'dict_idioms_2020_20260929',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.idiom_word_grid_puzzles (
  id uuid primary key default gen_random_uuid(),
  title text not null default '成語填字圖',
  published_on date not null default current_date,
  difficulty text not null default 'basic' check (difficulty in ('beginner', 'basic', 'advanced', 'challenge')),
  puzzle_data jsonb not null,
  source_version text not null default 'dict_idioms_2020_20260929',
  illustration_url text not null default '',
  is_daily_eligible boolean not null default true,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  created_by uuid references public.contact_book_profiles(id) on delete set null,
  updated_by uuid references public.contact_book_profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint idiom_word_grid_puzzle_data_object check (jsonb_typeof(puzzle_data) = 'object'),
  constraint idiom_word_grid_title_date_unique unique (title, published_on)
);

create index if not exists idiom_word_grid_puzzles_status_date_idx
  on public.idiom_word_grid_puzzles(status, published_on desc);

create table if not exists public.idiom_word_grid_wallets (
  student_id uuid primary key references public.students(id) on delete cascade,
  energy smallint not null default 0 check (energy between 0 and 20),
  updated_at timestamptz not null default now()
);

create table if not exists public.idiom_word_grid_completions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  puzzle_id uuid not null references public.idiom_word_grid_puzzles(id) on delete cascade,
  hints_used smallint not null default 0 check (hints_used >= 0),
  energy_earned smallint not null default 0 check (energy_earned between 0 and 4),
  completed_at timestamptz not null default now(),
  unique (student_id, puzzle_id)
);

create table if not exists public.idiom_word_grid_hints (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  puzzle_id uuid not null references public.idiom_word_grid_puzzles(id) on delete cascade,
  hint_kind text not null check (hint_kind in ('letter', 'cross', 'check')),
  cell_key text not null,
  energy_cost smallint not null check (energy_cost in (1, 2)),
  used_at timestamptz not null default now()
);

alter table public.idiom_entries enable row level security;
alter table public.idiom_word_grid_puzzles enable row level security;
alter table public.idiom_word_grid_wallets enable row level security;
alter table public.idiom_word_grid_completions enable row level security;
alter table public.idiom_word_grid_hints enable row level security;

drop policy if exists idiom_entries_public_read on public.idiom_entries;
create policy idiom_entries_public_read on public.idiom_entries
for select to anon, authenticated
using (is_active or public.can_manage_word_grid_puzzles());

drop policy if exists idiom_entries_admin_write on public.idiom_entries;
create policy idiom_entries_admin_write on public.idiom_entries
for all to authenticated
using (public.can_manage_word_grid_puzzles())
with check (public.can_manage_word_grid_puzzles());

drop policy if exists idiom_puzzles_public_read on public.idiom_word_grid_puzzles;
create policy idiom_puzzles_public_read on public.idiom_word_grid_puzzles
for select to anon, authenticated
using (status = 'published' or public.can_manage_word_grid_puzzles());

drop policy if exists idiom_puzzles_admin_write on public.idiom_word_grid_puzzles;
create policy idiom_puzzles_admin_write on public.idiom_word_grid_puzzles
for all to authenticated
using (public.can_manage_word_grid_puzzles())
with check (public.can_manage_word_grid_puzzles());

drop policy if exists idiom_wallet_self_read on public.idiom_word_grid_wallets;
create policy idiom_wallet_self_read on public.idiom_word_grid_wallets
for select to authenticated
using (exists (
  select 1 from public.students student
  where student.id = idiom_word_grid_wallets.student_id and student.profile_id = auth.uid()
));

drop policy if exists idiom_completion_self_read on public.idiom_word_grid_completions;
create policy idiom_completion_self_read on public.idiom_word_grid_completions
for select to authenticated
using (exists (
  select 1 from public.students student
  where student.id = idiom_word_grid_completions.student_id and student.profile_id = auth.uid()
));

drop policy if exists idiom_hint_self_read on public.idiom_word_grid_hints;
create policy idiom_hint_self_read on public.idiom_word_grid_hints
for select to authenticated
using (exists (
  select 1 from public.students student
  where student.id = idiom_word_grid_hints.student_id and student.profile_id = auth.uid()
));

grant select on public.idiom_entries to anon, authenticated;
grant insert, update, delete on public.idiom_entries to authenticated;
grant select on public.idiom_word_grid_puzzles to anon, authenticated;
grant insert, update, delete on public.idiom_word_grid_puzzles to authenticated;
grant select on public.idiom_word_grid_wallets, public.idiom_word_grid_completions, public.idiom_word_grid_hints to authenticated;

create or replace function public.spend_idiom_word_grid_hint(
  p_puzzle_id uuid,
  p_hint_kind text,
  p_cell_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_student_id uuid;
  hint_cost smallint;
  remaining_energy smallint;
begin
  if p_hint_kind not in ('letter', 'cross', 'check') then
    raise exception using errcode = '22023', message = 'invalid_idiom_hint_kind';
  end if;
  hint_cost := case when p_hint_kind = 'cross' then 2 else 1 end;

  select student.id into current_student_id
  from public.students student
  where student.profile_id = auth.uid() and student.is_active
  limit 1;
  if current_student_id is null then
    raise exception using errcode = 'P0001', message = 'student_required';
  end if;
  if not exists (
    select 1 from public.idiom_word_grid_puzzles puzzle
    where puzzle.id = p_puzzle_id and puzzle.status = 'published'
  ) then
    raise exception using errcode = 'P0001', message = 'idiom_puzzle_not_found';
  end if;

  insert into public.idiom_word_grid_wallets(student_id, energy)
  values (current_student_id, 0)
  on conflict (student_id) do nothing;

  update public.idiom_word_grid_wallets wallet
  set energy = wallet.energy - hint_cost,
      updated_at = now()
  where wallet.student_id = current_student_id
    and wallet.energy >= hint_cost
  returning wallet.energy into remaining_energy;

  if remaining_energy is null then
    raise exception using errcode = 'P0001', message = 'idiom_energy_insufficient';
  end if;

  insert into public.idiom_word_grid_hints(student_id, puzzle_id, hint_kind, cell_key, energy_cost)
  values (current_student_id, p_puzzle_id, p_hint_kind, p_cell_key, hint_cost);

  return jsonb_build_object('energy', remaining_energy, 'cost', hint_cost);
end;
$$;

create or replace function public.complete_idiom_word_grid(
  p_puzzle_id uuid,
  p_hints_used integer default 0,
  p_focus_task_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_student_id uuid;
  inserted_completion uuid;
  actual_hints_used integer := 0;
  earned smallint := 0;
  current_energy smallint;
begin
  if p_hints_used < 0 then
    raise exception using errcode = '22023', message = 'invalid_hints_used';
  end if;
  select student.id into current_student_id
  from public.students student
  where student.profile_id = auth.uid() and student.is_active
  limit 1;
  if current_student_id is null then
    raise exception using errcode = 'P0001', message = 'student_required';
  end if;
  if not exists (
    select 1 from public.idiom_word_grid_puzzles puzzle
    where puzzle.id = p_puzzle_id and puzzle.status = 'published'
  ) then
    raise exception using errcode = 'P0001', message = 'idiom_puzzle_not_found';
  end if;

  select count(*)::integer into actual_hints_used
  from public.idiom_word_grid_hints hint
  where hint.student_id = current_student_id and hint.puzzle_id = p_puzzle_id;

  insert into public.idiom_word_grid_completions(student_id, puzzle_id, hints_used, energy_earned)
  values (current_student_id, p_puzzle_id, least(actual_hints_used, 32767), case when actual_hints_used = 0 then 4 else 3 end)
  on conflict (student_id, puzzle_id) do nothing
  returning id into inserted_completion;

  if inserted_completion is not null then
    earned := case when actual_hints_used = 0 then 4 else 3 end;
  end if;

  insert into public.idiom_word_grid_wallets(student_id, energy, updated_at)
  values (current_student_id, earned, now())
  on conflict (student_id) do update
  set energy = least(20, public.idiom_word_grid_wallets.energy + earned),
      updated_at = now()
  returning energy into current_energy;

  if p_focus_task_id is not null then
    if not exists (
      select 1
      from public.student_focus_tasks task
      where task.id = p_focus_task_id
        and task.student_id = current_student_id
        and lower(task.subject_code_snapshot::text) = 'chinese'
        and lower(task.activity_code_snapshot::text) = 'idiom_word_grid'
    ) then
      raise exception using errcode = 'P0001', message = 'idiom_focus_task_invalid';
    end if;
    perform public.record_focus_task_attempt(p_focus_task_id, 100, 1, 1);
  end if;

  return jsonb_build_object(
    'energy', current_energy,
    'energyEarned', earned,
    'firstCompletion', inserted_completion is not null
  );
end;
$$;

revoke all on function public.spend_idiom_word_grid_hint(uuid, text, text) from public;
revoke all on function public.complete_idiom_word_grid(uuid, integer, uuid) from public;
grant execute on function public.spend_idiom_word_grid_hint(uuid, text, text) to authenticated;
grant execute on function public.complete_idiom_word_grid(uuid, integer, uuid) to authenticated;

insert into public.learning_systems (
  subject_code, subject_name, description, launch_url, display_order,
  weekly_minimum, weekly_maximum, audience_scope, is_active
) values (
  'chinese', '國文', '從成語填字圖練習字形、語意、典源與成語運用。',
  'https://shaujiun.github.io/SLJH-learning-hub/?puzzle=word-grid&mode=idiom',
  15, 1, 1, 'common', true
)
on conflict (subject_code) do update set
  subject_name = excluded.subject_name,
  description = excluded.description,
  launch_url = excluded.launch_url,
  display_order = excluded.display_order,
  weekly_minimum = 1,
  weekly_maximum = 1,
  audience_scope = excluded.audience_scope,
  is_active = true,
  updated_at = now();
insert into public.learning_activities (
  learning_system_id, activity_code, activity_name, launch_path,
  question_count_a, question_count_b, target_score, display_order, is_active
)
select
  id, 'idiom_word_grid', '成語填字圖', '?puzzle=word-grid&mode=idiom',
  1, 1, 100, 10, true
from public.learning_systems
where lower(subject_code::text) = 'chinese'
on conflict (learning_system_id, activity_code) do update set
  activity_name = excluded.activity_name,
  launch_path = excluded.launch_path,
  question_count_a = 1,
  question_count_b = 1,
  target_score = 100,
  display_order = excluded.display_order,
  is_active = true,
  updated_at = now();
