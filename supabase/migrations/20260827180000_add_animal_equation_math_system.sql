-- 數學科第一款桌遊「根式馬戲團」入口。八上第 2 章起適用；多人對戰先維持自由練習，不排入每日任務。
insert into public.learning_systems (
  subject_code,
  subject_name,
  description,
  launch_url,
  display_order,
  weekly_minimum,
  weekly_maximum,
  audience_scope,
  is_active
)
values (
  'math',
  '數學科',
  '以七、八年級內容建立數感、根式運算及多人桌遊練習。',
  'https://shaujiun.github.io/SLJH-learning-hub/?subject=math',
  20,
  1,
  1,
  'common',
  true
)
on conflict (subject_code) do update set
  subject_name = excluded.subject_name,
  description = excluded.description,
  launch_url = excluded.launch_url,
  display_order = excluded.display_order,
  audience_scope = excluded.audience_scope,
  is_active = excluded.is_active,
  updated_at = now();
