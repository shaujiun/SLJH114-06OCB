-- 填字圖：公開練習、管理者編題與可缺省的本期／前一期解答。

create or replace function public.can_manage_word_grid_puzzles()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.contact_book_is_admin();
$$;

revoke all on function public.can_manage_word_grid_puzzles() from public;
revoke all on function public.can_manage_word_grid_puzzles() from anon;
grant execute on function public.can_manage_word_grid_puzzles() to authenticated;

create or replace function public.is_word_grid_rows(rows text[])
returns boolean
language sql
immutable
set search_path = public
as $$
  select array_length(rows, 1) = 10
    and not exists (select 1 from unnest(rows) row_text where char_length(row_text) <> 10);
$$;

revoke all on function public.is_word_grid_rows(text[]) from public;

create table if not exists public.word_grid_puzzles (
  id uuid primary key default gen_random_uuid(),
  published_on date not null unique,
  title text not null default '填字圖',
  source_name text not null default '聯合報好讀周報',
  designer_name text not null default '遲驖川老師',
  grid_rows text[] not null,
  character_bank text[] not null,
  solution_rows text[],
  previous_answer_label text not null default '',
  previous_answer_rows text[],
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  published_at timestamptz,
  created_by uuid references public.contact_book_profiles(id) on delete set null,
  updated_by uuid references public.contact_book_profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint word_grid_rows_are_10_by_10 check (public.is_word_grid_rows(grid_rows)),
  constraint word_grid_solution_is_10_by_10 check (
    solution_rows is null or public.is_word_grid_rows(solution_rows)
  ),
  constraint word_grid_previous_answer_is_10_by_10 check (
    previous_answer_rows is null or public.is_word_grid_rows(previous_answer_rows)
  )
);

create index if not exists word_grid_puzzles_status_date_idx
  on public.word_grid_puzzles(status, published_on desc);

alter table public.word_grid_puzzles enable row level security;

drop policy if exists word_grid_puzzles_public_read on public.word_grid_puzzles;
create policy word_grid_puzzles_public_read on public.word_grid_puzzles
for select to anon, authenticated
using (status = 'published' or public.can_manage_word_grid_puzzles());

drop policy if exists word_grid_puzzles_admin_write on public.word_grid_puzzles;
create policy word_grid_puzzles_admin_write on public.word_grid_puzzles
for all to authenticated
using (public.can_manage_word_grid_puzzles())
with check (public.can_manage_word_grid_puzzles());

grant select on public.word_grid_puzzles to anon, authenticated;
grant insert, update, delete on public.word_grid_puzzles to authenticated;

insert into public.word_grid_puzzles (
  published_on,
  title,
  source_name,
  designer_name,
  grid_rows,
  character_bank,
  solution_rows,
  previous_answer_label,
  previous_answer_rows,
  status,
  published_at
)
values (
  '2026-08-31',
  '填字圖',
  '聯合報好讀周報',
  '遲驖川老師',
  array[
    '.麥##逢#.進..',
    '草#.向..住##奇',
    '..能#.#.眾..',
    '##.#.張##地#',
    '..#歸#.妮..頓',
    '.#人#學.##.#',
    '盡#.志.#...博',
    '.心###界#身##',
    '#.#.定#眼...',
    '...人#泡...調'
  ],
  array[
    '人','力','山','大','子','心','肉','手','民','土',
    '女','休','至','同','如','好','低','妹','原','高',
    '豈','脈','斯','就','量','間','測','想','意','電',
    '新','逢','圖','誇','寶','盡','影','繪','歡','鑑'
  ],
  null,
  '前一期答案尚未收錄',
  null,
  'published',
  now()
)
on conflict (published_on) do nothing;
