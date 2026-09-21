-- Store one shared ordered image gallery on every row in an honor group.
-- The seven-argument RPC overloads wrap the existing validated operations so
-- the honor rows and their shared images are committed in one transaction.

begin;

alter table public.honor_entries
  add column if not exists image_paths text[] not null default array[]::text[],
  add column if not exists image_alt_texts text[] not null default array[]::text[];

alter table public.honor_entries
  drop constraint if exists honor_entries_image_count_check,
  drop constraint if exists honor_entries_image_alt_count_check;

alter table public.honor_entries
  add constraint honor_entries_image_count_check
    check (cardinality(image_paths) <= 10),
  add constraint honor_entries_image_alt_count_check
    check (cardinality(image_paths) = cardinality(image_alt_texts));

create or replace function public.admin_create_honor_entries(
  p_class_id uuid,
  p_student_ids uuid[],
  p_title text,
  p_description text,
  p_awarded_on date,
  p_image_paths text[],
  p_image_alt_texts text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
  target_group_id uuid;
  normalized_paths text[] := coalesce(p_image_paths, array[]::text[]);
  normalized_alt_texts text[] := coalesce(p_image_alt_texts, array[]::text[]);
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.can_manage_class(p_class_id) then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if cardinality(normalized_paths) > 10
    or cardinality(normalized_paths) <> cardinality(normalized_alt_texts)
    or exists (
      select 1
      from unnest(normalized_paths) image_path
      where image_path not like p_class_id::text || '/honors/%'
    ) then
    raise exception 'invalid_honor_images';
  end if;

  result := public.admin_create_honor_entries(
    p_class_id,
    p_student_ids,
    p_title,
    p_description,
    p_awarded_on
  );
  target_group_id := (result ->> 'honorGroupId')::uuid;

  update public.honor_entries
  set image_paths = normalized_paths,
      image_alt_texts = normalized_alt_texts
  where honor_group_id = target_group_id;

  return result || jsonb_build_object('imageCount', cardinality(normalized_paths));
end;
$$;

revoke all on function public.admin_create_honor_entries(
  uuid, uuid[], text, text, date, text[], text[]
) from public, anon, authenticated;
grant execute on function public.admin_create_honor_entries(
  uuid, uuid[], text, text, date, text[], text[]
) to authenticated;

create or replace function public.admin_update_honor_group(
  p_honor_group_id uuid,
  p_student_ids uuid[],
  p_title text,
  p_description text,
  p_awarded_on date,
  p_image_paths text[],
  p_image_alt_texts text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  result jsonb;
  target_class_id uuid;
  normalized_paths text[] := coalesce(p_image_paths, array[]::text[]);
  normalized_alt_texts text[] := coalesce(p_image_alt_texts, array[]::text[]);
begin
  select entry.class_id into target_class_id
  from public.honor_entries entry
  where entry.honor_group_id = p_honor_group_id
  limit 1;

  if target_class_id is null then raise exception 'invalid_honor_entry'; end if;
  if not public.can_manage_class(target_class_id) then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if cardinality(normalized_paths) > 10
    or cardinality(normalized_paths) <> cardinality(normalized_alt_texts)
    or exists (
      select 1
      from unnest(normalized_paths) image_path
      where image_path not like target_class_id::text || '/honors/%'
    ) then
    raise exception 'invalid_honor_images';
  end if;

  result := public.admin_update_honor_group(
    p_honor_group_id,
    p_student_ids,
    p_title,
    p_description,
    p_awarded_on
  );

  update public.honor_entries
  set image_paths = normalized_paths,
      image_alt_texts = normalized_alt_texts
  where honor_group_id = p_honor_group_id;

  return result || jsonb_build_object('imageCount', cardinality(normalized_paths));
end;
$$;

revoke all on function public.admin_update_honor_group(
  uuid, uuid[], text, text, date, text[], text[]
) from public, anon, authenticated;
grant execute on function public.admin_update_honor_group(
  uuid, uuid[], text, text, date, text[], text[]
) to authenticated;

commit;
