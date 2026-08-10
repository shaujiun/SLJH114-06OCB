-- 依函式實際縮排移除被 FOR 迴圈自動變數遮蔽的宣告。

do $migration$
declare
  function_definition text;
begin
  select pg_get_functiondef('public.ensure_student_focus_week(date)'::regprocedure)
  into function_definition;

  function_definition := regexp_replace(
    function_definition,
    E'\n[[:space:]]*task_index integer;\n',
    E'\n',
    'g'
  );

  execute function_definition;
end;
$migration$;
