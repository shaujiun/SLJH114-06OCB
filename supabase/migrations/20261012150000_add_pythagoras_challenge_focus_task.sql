-- 將畢氏定理挑戰賽加入既有數學每日任務活動池。
-- 數學科每週派發量仍由 learning_systems 的 weekly_minimum / weekly_maximum 控制；
-- 本 migration 不提高每週任務數，只讓系統在既有數學活動中隨機選擇。

insert into public.learning_activities (
  learning_system_id,
  activity_code,
  activity_name,
  launch_path,
  question_count_a,
  question_count_b,
  target_score,
  display_order,
  is_active
)
select
  id,
  'pythagoras_challenge',
  '畢氏定理挑戰賽（測驗類）',
  '&game=pythagoras-challenge',
  10,
  10,
  100,
  10,
  true
from public.learning_systems
where lower(subject_code::text) = 'math'
on conflict (learning_system_id, activity_code) do update set
  activity_name = excluded.activity_name,
  launch_path = excluded.launch_path,
  question_count_a = excluded.question_count_a,
  question_count_b = excluded.question_count_b,
  target_score = excluded.target_score,
  display_order = excluded.display_order,
  is_active = excluded.is_active,
  updated_at = now();
