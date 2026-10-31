-- 報紙右側倒置區是同一期解答；另存逐題解答說明供學生完成後查閱。

alter table public.word_grid_puzzles
  add column if not exists answer_explanation text not null default '';

comment on column public.word_grid_puzzles.answer_explanation is
  '當期填字圖的解答說明，保留換行並於學生主動展開解答區時顯示。';
