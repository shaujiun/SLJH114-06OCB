-- 移除 ensure_student_focus_week 中被 FOR 迴圈自動變數遮蔽的多餘宣告。

do $migration$
declare
  function_definition text;
begin
  select pg_get_functiondef('public.ensure_student_focus_week(date)'::regprocedure)
  into function_definition;

  function_definition := replace(
    function_definition,
    E'\n    task_index integer;\n',
    E'\n'
  );

  execute function_definition;
end;
$migration$;
