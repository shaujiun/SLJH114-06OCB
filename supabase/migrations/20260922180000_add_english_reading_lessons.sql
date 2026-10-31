-- 英語閱讀：只供已核准、仍有效的學生帳號於開放期間閱讀。
-- 不按班級硬編碼；日後新增班級仍使用相同規則。原始報紙照片不進入公開儲存空間。

create or replace function public.is_active_learning_student()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null and exists (
    select 1
    from public.students student
    join public.contact_book_profiles profile on profile.id = student.profile_id
    where student.profile_id = auth.uid()
      and student.is_active
      and profile.user_type = 'student'
      and profile.approval_status = 'approved'
      and profile.is_active
  );
$$;

revoke all on function public.is_active_learning_student() from public;
revoke all on function public.is_active_learning_student() from anon;
grant execute on function public.is_active_learning_student() to authenticated;

create or replace function public.can_manage_english_reading()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.contact_book_is_admin();
$$;

revoke all on function public.can_manage_english_reading() from public;
revoke all on function public.can_manage_english_reading() from anon;
grant execute on function public.can_manage_english_reading() to authenticated;

create table if not exists public.english_reading_lessons (
  id uuid primary key default gen_random_uuid(),
  issue_on date,
  title text not null default '',
  author_name text not null default '',
  source_name text not null default '聯合報好讀周報',
  english_text text not null default '',
  translation_text text not null default '',
  grammar_text text not null default '',
  core_words text not null default '',
  extra_words text not null default '',
  mind_map_text text not null default '',
  cloze_text text not null default '',
  questions_text text not null default '',
  group_a_hint text not null default '',
  group_b_hint text not null default '',
  usage_note text not null default '',
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  available_from date,
  available_until date,
  published_at timestamptz,
  created_by uuid references public.contact_book_profiles(id) on delete set null,
  updated_by uuid references public.contact_book_profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint english_reading_availability_valid check (
    (available_from is null and available_until is null)
    or (available_from is not null and available_until is not null and available_until >= available_from)
  ),
  constraint english_reading_published_complete check (
    status <> 'published' or (
      available_from is not null and available_until is not null
      and length(trim(title)) > 0 and length(trim(english_text)) > 0
      and length(trim(usage_note)) > 0
    )
  )
);

create index if not exists english_reading_lessons_status_dates_idx
  on public.english_reading_lessons(status, available_from, available_until);

alter table public.english_reading_lessons enable row level security;

create policy english_reading_admin_all on public.english_reading_lessons
  for all to authenticated
  using (public.can_manage_english_reading())
  with check (public.can_manage_english_reading());

create policy english_reading_student_select on public.english_reading_lessons
  for select to authenticated
  using (
    status = 'published'
    and available_from <= (now() at time zone 'Asia/Taipei')::date
    and available_until >= (now() at time zone 'Asia/Taipei')::date
    and public.is_active_learning_student()
  );

revoke all on public.english_reading_lessons from public, anon;
grant select, insert, update, delete on public.english_reading_lessons to authenticated;
