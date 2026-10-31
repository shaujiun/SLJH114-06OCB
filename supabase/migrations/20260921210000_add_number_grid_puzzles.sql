-- 十拿九穩：管理者編題，未確認答案的草稿不對學生公開。

create table if not exists public.number_grid_puzzles (
  id uuid primary key default gen_random_uuid(),
  issue_on date not null unique,
  title text not null default '十拿九穩之變形挑戰',
  source_name text not null default '聯合報好讀周報',
  designer_name text not null default '狄運來老師',
  cells jsonb not null,
  circle_clues jsonb not null default '[]'::jsonb,
  line_clues jsonb not null default '[]'::jsonb,
  solution smallint[],
  explanation text not null default '',
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  published_at timestamptz,
  created_by uuid references public.contact_book_profiles(id) on delete set null,
  updated_by uuid references public.contact_book_profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint number_grid_cells_are_array check (jsonb_typeof(cells) = 'array'),
  constraint number_grid_circles_are_array check (jsonb_typeof(circle_clues) = 'array'),
  constraint number_grid_lines_are_array check (jsonb_typeof(line_clues) = 'array'),
  constraint number_grid_published_requires_answer check (
    status <> 'published' or (
      coalesce(array_length(solution, 1), 0) = 9
      and array_position(solution, null) is null
      and length(trim(explanation)) > 0
    )
  )
);

create index if not exists number_grid_puzzles_status_date_idx
  on public.number_grid_puzzles(status, issue_on desc);

alter table public.number_grid_puzzles enable row level security;

create policy number_grid_puzzles_public_read on public.number_grid_puzzles
for select to anon, authenticated
using (status = 'published' or public.can_manage_word_grid_puzzles());

create policy number_grid_puzzles_admin_write on public.number_grid_puzzles
for all to authenticated
using (public.can_manage_word_grid_puzzles())
with check (public.can_manage_word_grid_puzzles());

grant select on public.number_grid_puzzles to anon, authenticated;
grant insert, update, delete on public.number_grid_puzzles to authenticated;
