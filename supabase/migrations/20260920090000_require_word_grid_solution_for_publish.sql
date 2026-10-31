-- 填字圖必須等答案確認並收錄完整解答後，才能對學生發布。

update public.word_grid_puzzles
set
  status = 'draft',
  published_at = null,
  updated_at = now()
where status = 'published'
  and solution_rows is null;

create or replace function public.is_complete_word_grid_solution(grid_rows text[], solution_rows text[])
returns boolean
language sql
immutable
set search_path = public
as $$
  select solution_rows is not null
    and public.is_word_grid_rows(solution_rows)
    and not exists (
      select 1
      from generate_series(1, 10) row_index
      cross join generate_series(1, 10) column_index
      where case
        when substring(grid_rows[row_index] from column_index for 1) = '#'
          then substring(solution_rows[row_index] from column_index for 1) <> '#'
        when substring(grid_rows[row_index] from column_index for 1) = '.'
          then substring(solution_rows[row_index] from column_index for 1) in ('#', '.')
        else substring(solution_rows[row_index] from column_index for 1)
          <> substring(grid_rows[row_index] from column_index for 1)
      end
    );
$$;

revoke all on function public.is_complete_word_grid_solution(text[], text[]) from public;

alter table public.word_grid_puzzles
drop constraint if exists word_grid_published_requires_solution;

alter table public.word_grid_puzzles
add constraint word_grid_published_requires_solution
check (status <> 'published' or public.is_complete_word_grid_solution(grid_rows, solution_rows));
