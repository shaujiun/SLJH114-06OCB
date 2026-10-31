-- 地理科第一階段：先開放翰林八上中國地理填圖自由練習。
-- 尚未加入 learning_activities，因此不會排入每日或每週專注任務。

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
  'geography',
  '地理科',
  '依翰林版課本練習臺灣、中國與世界地理；第一階段先開放中國行政區、地形、河流與氣候。',
  'https://shaujiun.github.io/SLJH-learning-hub/?subject=geography',
  40,
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
  weekly_minimum = excluded.weekly_minimum,
  weekly_maximum = excluded.weekly_maximum,
  audience_scope = excluded.audience_scope,
  is_active = excluded.is_active,
  updated_at = now();
