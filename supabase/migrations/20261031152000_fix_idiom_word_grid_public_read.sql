-- 匿名讀取已發布成語題目時，不執行只授權管理者的函式。

drop policy if exists idiom_entries_public_read on public.idiom_entries;

create policy idiom_entries_active_read on public.idiom_entries
for select to anon, authenticated
using (is_active);

create policy idiom_entries_admin_read on public.idiom_entries
for select to authenticated
using (public.can_manage_word_grid_puzzles());

drop policy if exists idiom_puzzles_public_read on public.idiom_word_grid_puzzles;

create policy idiom_puzzles_published_read on public.idiom_word_grid_puzzles
for select to anon, authenticated
using (status = 'published');

create policy idiom_puzzles_admin_read on public.idiom_word_grid_puzzles
for select to authenticated
using (public.can_manage_word_grid_puzzles());
