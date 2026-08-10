-- 歷史題庫：清楚區分教師自編題與有來源的歷屆題，並保留選項、媒體及自動分類資訊。

with seed_events(event_code, chapter_code, title, start_year, end_year, display_date, region, category, importance, summary, source_note, display_order) as (
  values
    ('h3c2-09', 'hanlin-8-1-02', '諸子百家', -500, null::integer, '約西元前 5 世紀', 'china', 'society', 3, '春秋戰國時期思想家針對政治、社會與人生提出不同主張。', '為正式歷屆題建立的精確對應事件，發布前仍由管理者確認。', 90),
    ('h3c2-10', 'hanlin-8-1-02', '造紙術改進', 105, null::integer, '約西元 105 年', 'china', 'society', 2, '東漢時期改進造紙技術，使書寫材料更容易製作與傳播。', '為正式歷屆題建立的精確對應事件，發布前仍由管理者確認。', 100),
    ('h3c2-11', 'hanlin-8-1-02', '日本大化革新', 646, null::integer, '西元 646 年', 'japan', 'politics', 3, '日本仿效隋唐制度推動中央集權改革，並持續吸收東亞文化。', '為正式歷屆題建立的精確對應事件，發布前仍由管理者確認。', 110),
    ('h3c3-09', 'hanlin-8-1-03', '宋代理學與朱熹', 1130, 1200, '南宋時期', 'china', 'society', 2, '朱熹集理學之大成，《四書集注》深刻影響後世教育與科舉。', '為正式歷屆題建立的精確對應事件，發布前仍由管理者確認。', 90),
    ('h3c5-09', 'hanlin-8-1-05', '英法聯軍', 1856, 1860, '西元 1856～1860 年', 'china', 'war', 3, '英法聯軍迫使清朝簽訂更多不平等條約，外國勢力進一步深入中國。', '為正式歷屆題建立的精確對應事件，發布前仍由管理者確認。', 90),
    ('h3c5-10', 'hanlin-8-1-05', '廣州一口通商', 1757, 1842, '西元 1757～1842 年', 'china', 'economy', 2, '清朝限制西方商人只能在廣州經由公行進行貿易。', '為正式歷屆題建立的精確對應事件，發布前仍由管理者確認。', 100),
    ('h4c3-09', 'hanlin-8-2-03', '日俄戰爭', 1904, 1905, '西元 1904～1905 年', 'japan', 'war', 2, '日本戰勝俄國，改變東亞權力平衡，也刺激中國改革與立憲聲浪。', '為正式歷屆題建立的精確對應事件，發布前仍由管理者確認。', 90),
    ('h4c5-09', 'hanlin-8-2-05', '六四天安門事件', 1989, null::integer, '西元 1989 年', 'china', 'politics', 2, '北京學生與民眾的政治改革訴求遭政府武力鎮壓。', '為正式歷屆題建立的精確對應事件，發布前仍由管理者確認。', 90)
)
insert into public.history_events (
  event_code, chapter_id, title, start_year, end_year, display_date, region, category,
  importance, summary, source_note, display_order, status
)
select
  seed.event_code, chapter.id, seed.title, seed.start_year, seed.end_year, seed.display_date,
  seed.region, seed.category, seed.importance, seed.summary, seed.source_note, seed.display_order, 'draft'
from seed_events seed
join public.history_chapters chapter on chapter.chapter_code = seed.chapter_code
on conflict (event_code) do nothing;

create table if not exists public.history_questions (
  id uuid primary key default gen_random_uuid(),
  question_code citext not null unique,
  event_id uuid not null references public.history_events(id) on delete cascade,
  question_type text not null check (question_type in ('practice', 'past')),
  prompt text not null,
  options jsonb not null default '[]'::jsonb,
  media_urls jsonb not null default '[]'::jsonb,
  question_tables jsonb not null default '[]'::jsonb,
  answer text not null,
  explanation text not null default '',
  source_name text not null default '',
  source_year text not null default '',
  source_url text not null default '',
  original_event_ids text[] not null default '{}',
  mapping_confidence smallint not null default 0 check (mapping_confidence between 0 and 100),
  mapping_note text not null default '',
  display_order integer not null default 0,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  published_at timestamptz,
  created_by uuid references public.contact_book_profiles(id) on delete set null,
  updated_by uuid references public.contact_book_profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint history_past_question_source_required check (
    question_type <> 'past' or length(btrim(source_name)) > 0
  ),
  constraint history_question_options_array check (jsonb_typeof(options) = 'array'),
  constraint history_question_media_array check (jsonb_typeof(media_urls) = 'array'),
  constraint history_question_tables_array check (jsonb_typeof(question_tables) = 'array')
);

alter table public.history_questions add column if not exists options jsonb not null default '[]'::jsonb;
alter table public.history_questions add column if not exists media_urls jsonb not null default '[]'::jsonb;
alter table public.history_questions add column if not exists question_tables jsonb not null default '[]'::jsonb;
alter table public.history_questions add column if not exists original_event_ids text[] not null default '{}';
alter table public.history_questions add column if not exists mapping_confidence smallint not null default 0;
alter table public.history_questions add column if not exists mapping_note text not null default '';

create index if not exists history_questions_event_status_idx
  on public.history_questions(event_id, status, display_order);

alter table public.history_questions enable row level security;

drop policy if exists history_questions_authenticated_read on public.history_questions;
create policy history_questions_authenticated_read on public.history_questions
for select to authenticated
using (status = 'published' or public.can_manage_history_content());

drop policy if exists history_questions_manager_write on public.history_questions;
create policy history_questions_manager_write on public.history_questions
for all to authenticated
using (public.can_manage_history_content())
with check (public.can_manage_history_content());

grant select, insert, update, delete on public.history_questions to authenticated;
