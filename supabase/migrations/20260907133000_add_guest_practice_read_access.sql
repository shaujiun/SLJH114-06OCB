-- 訪客只可讀取已公開的學習內容；學生、任務、作答與管理資料維持原有權限。

drop policy if exists history_chapters_anon_read on public.history_chapters;
create policy history_chapters_anon_read on public.history_chapters
for select to anon
using (is_active = true);

drop policy if exists history_events_anon_read on public.history_events;
create policy history_events_anon_read on public.history_events
for select to anon
using (status = 'published');

drop policy if exists history_questions_anon_read on public.history_questions;
create policy history_questions_anon_read on public.history_questions
for select to anon
using (status = 'published');

drop policy if exists schulte_phrase_items_anon_read on public.schulte_phrase_items;
create policy schulte_phrase_items_anon_read on public.schulte_phrase_items
for select to anon
using (is_active = true);

grant select on public.history_chapters to anon;
grant select on public.history_events to anon;
grant select on public.history_questions to anon;
grant select on public.schulte_phrase_items to anon;
