-- 詩句與名言重組：教師題庫、個人紀錄與每日任務回寫。

create or replace function public.can_manage_focus_content()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.contact_book_is_admin() or exists (
    select 1
    from public.contact_book_profiles profile
    where profile.id = auth.uid()
      and profile.is_active
      and profile.approval_status = 'approved'
      and lower(profile.user_type::text) <> 'student'
  );
$$;

revoke all on function public.can_manage_focus_content() from public;
revoke all on function public.can_manage_focus_content() from anon;
grant execute on function public.can_manage_focus_content() to authenticated;

create table if not exists public.schulte_phrase_items (
  id uuid primary key default gen_random_uuid(),
  category text not null default 'quote' check (category in ('poem', 'quote')),
  title text not null check (char_length(trim(title)) between 1 and 50),
  content text not null unique check (char_length(trim(content)) between 2 and 120),
  meaning text not null check (char_length(trim(meaning)) between 2 and 240),
  source text not null default '' check (char_length(source) <= 80),
  distractor_characters text not null default '' check (char_length(distractor_characters) <= 120),
  is_active boolean not null default true,
  created_by uuid references public.contact_book_profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.schulte_phrase_items enable row level security;

drop policy if exists schulte_phrase_items_authenticated_read on public.schulte_phrase_items;
create policy schulte_phrase_items_authenticated_read on public.schulte_phrase_items
for select to authenticated
using (is_active or public.can_manage_focus_content());

drop policy if exists schulte_phrase_items_manager_write on public.schulte_phrase_items;
create policy schulte_phrase_items_manager_write on public.schulte_phrase_items
for all to authenticated
using (public.can_manage_focus_content())
with check (public.can_manage_focus_content());

insert into public.schulte_phrase_items(category, title, content, meaning, source)
values
  ('quote', '學而時習之', '學而時習之，不亦說乎。', '學到知識後常常溫習，也是一件令人喜悅的事。', '《論語・學而》'),
  ('quote', '生於憂患', '生於憂患，死於安樂。', '保持警覺並面對磨練，能幫助人成長；沉溺安逸可能帶來危機。', '《孟子・告子下》'),
  ('poem', '春曉', '春眠不覺曉，處處聞啼鳥。', '春夜睡得安穩，不知不覺天亮了，到處都聽得到鳥叫聲。', '唐・孟浩然')
on conflict (content) do update set
  category = excluded.category,
  title = excluded.title,
  meaning = excluded.meaning,
  source = excluded.source,
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
  'schulte_sentence',
  '詩句與名言重組',
  'game=schulte-phrase',
  1,
  1,
  100,
  80,
  true
from public.learning_systems system
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

create or replace function public.record_phrase_schulte_attempt(
  p_focus_task_id uuid default null,
  p_phrase_id uuid default null,
  p_character_count integer default 2,
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
  if p_character_count < 2 or p_character_count > 100 then
    raise exception using errcode = '22023', message = 'invalid_phrase_character_count';
  end if;
  if p_duration_ms < 1 or p_duration_ms > 3600000 then
    raise exception using errcode = '22023', message = 'invalid_schulte_duration';
  end if;
  if p_error_count < 0 or p_error_count > 9999 then
    raise exception using errcode = '22023', message = 'invalid_schulte_error_count';
  end if;
  if p_phrase_id is not null and not exists (
    select 1 from public.schulte_phrase_items item where item.id = p_phrase_id
  ) then
    raise exception using errcode = '22023', message = 'phrase_not_found';
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
      and lower(task.activity_code_snapshot::text) = 'schulte_sentence'
    for update;
    if selected_task.id is null then
      raise exception using errcode = 'P0001', message = 'schulte_focus_task_not_found';
    end if;
  end if;

  insert into public.schulte_attempts (
    student_id, focus_task_id, mode, grid_size, duration_ms, error_count, average_tap_ms
  ) values (
    current_student_id,
    p_focus_task_id,
    'sentence',
    p_character_count,
    p_duration_ms,
    p_error_count,
    round(p_duration_ms::numeric / p_character_count)::integer
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
    and attempt.mode = 'sentence';

  return jsonb_build_object(
    'attemptId', inserted_attempt.id,
    'taskCompleted', selected_task.id is not null,
    'personalBestMs', personal_best_ms
  );
end;
$$;

revoke all on function public.record_phrase_schulte_attempt(uuid, uuid, integer, integer, integer) from public;
grant execute on function public.record_phrase_schulte_attempt(uuid, uuid, integer, integer, integer) to authenticated;
