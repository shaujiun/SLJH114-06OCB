-- 公開題目與管理者草稿分開授權，避免匿名請求執行管理者函式。

drop policy if exists word_grid_puzzles_public_read on public.word_grid_puzzles;

create policy word_grid_puzzles_published_read on public.word_grid_puzzles
for select to anon, authenticated
using (status = 'published');

create policy word_grid_puzzles_admin_read on public.word_grid_puzzles
for select to authenticated
using (public.can_manage_word_grid_puzzles());
