-- 匿名讀取已發布題目時，不應執行只授權管理者的函式。

drop policy if exists number_grid_puzzles_public_read on public.number_grid_puzzles;

create policy number_grid_puzzles_published_read on public.number_grid_puzzles
for select to anon, authenticated
using (status = 'published');

create policy number_grid_puzzles_admin_read on public.number_grid_puzzles
for select to authenticated
using (public.can_manage_word_grid_puzzles());
