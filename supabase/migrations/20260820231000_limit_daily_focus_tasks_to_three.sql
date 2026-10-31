-- 每日專注任務改為最多 3 項，並讓 2 項最常見、1 項其次、3 項最少。
-- 已經建立的週任務不重排；新規則套用於之後首次建立的學生週任務。
do $migration$
declare
  function_definition text;
  old_exit_block text := $old$
        exit when daily_count < 4
          and (lower(system_row.subject_code::text) <> 'focus_training' or same_system_daily_count = 0);$old$;
  new_exit_block text := $new$
        exit when daily_count < 3
          and (lower(system_row.subject_code::text) <> 'focus_training' or same_system_daily_count = 0)
          and case daily_count
            when 0 then random() < 0.625
            when 1 then true
            else random() < 0.125
          end;$new$;
begin
  select pg_get_functiondef('public.ensure_student_focus_week(date)'::regprocedure)
  into function_definition;

  if position(old_exit_block in function_definition) = 0 then
    raise exception 'ensure_student_focus_week allocation block was not found';
  end if;

  function_definition := replace(function_definition, old_exit_block, new_exit_block);
  function_definition := replace(function_definition, 'if daily_count >= 4', 'if daily_count >= 3');

  execute function_definition;
end;
$migration$;
