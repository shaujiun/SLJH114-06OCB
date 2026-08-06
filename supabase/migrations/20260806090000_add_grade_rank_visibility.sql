begin;

alter table public.classes
  add column if not exists show_class_rank boolean not null default false,
  add column if not exists show_school_rank boolean not null default false;

create or replace function public.admin_set_grade_rank_visibility(
  p_class_id uuid,
  p_show_class_rank boolean,
  p_show_school_rank boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_show_class_rank is null or p_show_school_rank is null then
    raise exception 'invalid_rank_visibility';
  end if;
  if not exists (
    select 1 from public.classes class_row
    where class_row.id = p_class_id and class_row.is_active
  ) then raise exception 'invalid_class'; end if;
  if not public.can_manage_class(p_class_id) then
    raise exception 'permission_denied' using errcode = '42501';
  end if;

  update public.classes
  set show_class_rank = p_show_class_rank,
      show_school_rank = p_show_school_rank,
      updated_at = now()
  where id = p_class_id;

  return jsonb_build_object(
    'classId', p_class_id,
    'showClassRank', p_show_class_rank,
    'showSchoolRank', p_show_school_rank
  );
end;
$$;

revoke all on function public.admin_set_grade_rank_visibility(uuid, boolean, boolean)
  from public, anon, authenticated;
grant execute on function public.admin_set_grade_rank_visibility(uuid, boolean, boolean)
  to authenticated;

commit;
