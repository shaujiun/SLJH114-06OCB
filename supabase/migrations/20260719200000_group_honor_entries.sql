-- Group multiple student rows into one public honor item.

alter table public.honor_entries
add column if not exists honor_group_id uuid;

update public.honor_entries
set honor_group_id = gen_random_uuid()
where honor_group_id is null;

alter table public.honor_entries
alter column honor_group_id set default gen_random_uuid();

alter table public.honor_entries
alter column honor_group_id set not null;

create index if not exists honor_entries_group_idx
  on public.honor_entries(honor_group_id);

create or replace function public.admin_create_honor_entries(
  p_class_id uuid,
  p_student_ids uuid[],
  p_title text,
  p_description text,
  p_awarded_on date
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text;
  v_description text;
  v_student_ids uuid[];
  v_student_count integer;
  v_group_id uuid := gen_random_uuid();
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not public.can_manage_class(p_class_id) then
    raise exception 'permission_denied';
  end if;

  select array_agg(distinct selected_id)
  into v_student_ids
  from unnest(coalesce(p_student_ids, array[]::uuid[])) as selected(selected_id);

  if coalesce(cardinality(v_student_ids), 0) < 1
     or cardinality(v_student_ids) > 50 then
    raise exception 'invalid_honor_students';
  end if;

  select count(*)
  into v_student_count
  from public.students s
  where s.id = any(v_student_ids)
    and s.class_id = p_class_id
    and s.is_active;

  if v_student_count <> cardinality(v_student_ids) then
    raise exception 'invalid_class_student';
  end if;

  v_title := regexp_replace(btrim(coalesce(p_title, '')), '\s+', ' ', 'g');
  v_description := btrim(coalesce(p_description, ''));
  if char_length(v_title) < 1 or char_length(v_title) > 80 then
    raise exception 'invalid_honor_title';
  end if;
  if char_length(v_description) > 1000 then
    raise exception 'invalid_honor_description';
  end if;
  if p_awarded_on is null then
    raise exception 'invalid_awarded_on';
  end if;

  insert into public.honor_entries (
    honor_group_id,
    class_id,
    student_id,
    student_display_name,
    title,
    description,
    awarded_on,
    created_by,
    is_visible
  )
  select
    v_group_id,
    p_class_id,
    s.id,
    s.full_name,
    v_title,
    nullif(v_description, ''),
    p_awarded_on,
    auth.uid(),
    true
  from public.students s
  where s.id = any(v_student_ids)
  order by s.seat_number;

  return jsonb_build_object(
    'honorGroupId', v_group_id,
    'studentCount', v_student_count,
    'title', v_title,
    'awardedOn', p_awarded_on
  );
end;
$$;

revoke all on function public.admin_create_honor_entries(uuid, uuid[], text, text, date) from public;
revoke all on function public.admin_create_honor_entries(uuid, uuid[], text, text, date) from anon;
grant execute on function public.admin_create_honor_entries(uuid, uuid[], text, text, date) to authenticated;

create or replace function public.admin_set_honor_group_visibility(
  p_honor_group_id uuid,
  p_is_visible boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_class_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select h.class_id
  into v_class_id
  from public.honor_entries h
  where h.honor_group_id = p_honor_group_id
  limit 1;

  if v_class_id is null then
    raise exception 'invalid_honor_entry';
  end if;
  if not public.can_manage_class(v_class_id) then
    raise exception 'permission_denied';
  end if;

  update public.honor_entries
  set is_visible = p_is_visible
  where honor_group_id = p_honor_group_id;
end;
$$;

revoke all on function public.admin_set_honor_group_visibility(uuid, boolean) from public;
revoke all on function public.admin_set_honor_group_visibility(uuid, boolean) from anon;
grant execute on function public.admin_set_honor_group_visibility(uuid, boolean) to authenticated;
