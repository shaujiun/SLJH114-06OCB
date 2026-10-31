-- 地理填圖納入每日任務：學生任選已開放章節完成一回合，達 80 分即完成。
-- 既有週任務不重排；本設定從學生下一次建立新的一週任務時生效。

update public.learning_systems
set description = '依翰林版課本章節練習臺灣、中國與世界地理，包含位置、地形、氣候、水文與區域特色。',
    weekly_minimum = 1,
    weekly_maximum = 3,
    updated_at = now()
where lower(subject_code::text) = 'geography';

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
  system.id,
  'geography_round',
  '地理填圖任選一回合',
  '&geography=maps',
  10,
  10,
  80,
  10,
  true
from public.learning_systems system
where lower(system.subject_code::text) = 'geography'
on conflict (learning_system_id, activity_code) do update set
  activity_name = excluded.activity_name,
  launch_path = excluded.launch_path,
  question_count_a = excluded.question_count_a,
  question_count_b = excluded.question_count_b,
  target_score = excluded.target_score,
  display_order = excluded.display_order,
  is_active = excluded.is_active,
  updated_at = now();
