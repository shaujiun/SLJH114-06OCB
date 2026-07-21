-- Edit a grouped honor entry without losing its visibility state or the IDs
-- of students who remain in the group.

begin;

alter table public.honor_entries
  add column if not exists last_updated_by uuid
    references public.contact_book_profiles(id) on delete set null;

update public.honor_entries
set last_updated_by = created_by
where last_updated_by is null;

create unique index if not exists honor_entries_group_student_unique
  on public.honor_entries(honor_group_id, student_id);

create or replace function public.admin_update_honor_group(
  p_honor_group_id uuid,
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
  target_class_id uuid;
  target_visibility boolean;
  normalized_title text;
  normalized_description text;
  selected_student_ids uuid[];
  valid_student_count integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  select entry.class_id, entry.is_visible
  into target_class_id, target_visibility
  from public.honor_entries entry
  where entry.honor_group_id = p_honor_group_id
  limit 1
  for update;
  if target_class_id is null then raise exception 'invalid_honor_entry'; end if;
  if not public.can_manage_class(target_class_id) then
    raise exception 'permission_denied' using errcode = '42501';
  end if;

  select array_agg(distinct selected_id)
  into selected_student_ids
  from unnest(coalesce(p_student_ids, array[]::uuid[])) as selected(selected_id);
  if coalesce(cardinality(selected_student_ids), 0) < 1
    or cardinality(selected_student_ids) > 50 then
    raise exception 'invalid_honor_students';
  end if;

  select count(*) into valid_student_count
  from public.students student
  where student.id = any(selected_student_ids)
    and student.class_id = target_class_id
    and student.is_active;
  if valid_student_count <> cardinality(selected_student_ids) then
    raise exception 'invalid_class_student';
  end if;

  normalized_title := regexp_replace(btrim(coalesce(p_title, '')), '\s+', ' ', 'g');
  normalized_description := btrim(coalesce(p_description, ''));
  if char_length(normalized_title) < 1 or char_length(normalized_title) > 80
    or char_length(normalized_description) > 1000
    or p_awarded_on is null then
    raise exception 'invalid_honor';
  end if;

  update public.honor_entries entry
  set student_display_name = student.full_name,
      title = normalized_title,
      description = nullif(normalized_description, ''),
      awarded_on = p_awarded_on,
      last_updated_by = auth.uid()
  from public.students student
  where entry.honor_group_id = p_honor_group_id
    and entry.student_id = student.id
    and entry.student_id = any(selected_student_ids);

  delete from public.honor_entries entry
  where entry.honor_group_id = p_honor_group_id
    and not (entry.student_id = any(selected_student_ids));

  insert into public.honor_entries (
    honor_group_id,
    class_id,
    student_id,
    student_display_name,
    title,
    description,
    awarded_on,
    created_by,
    last_updated_by,
    is_visible
  )
  select
    p_honor_group_id,
    target_class_id,
    student.id,
    student.full_name,
    normalized_title,
    nullif(normalized_description, ''),
    p_awarded_on,
    auth.uid(),
    auth.uid(),
    target_visibility
  from public.students student
  where student.id = any(selected_student_ids)
    and not exists (
      select 1
      from public.honor_entries existing
      where existing.honor_group_id = p_honor_group_id
        and existing.student_id = student.id
    );

  return jsonb_build_object(
    'honorGroupId', p_honor_group_id,
    'studentCount', valid_student_count,
    'title', normalized_title,
    'awardedOn', p_awarded_on,
    'isVisible', target_visibility
  );
end;
$$;

revoke all on function public.admin_update_honor_group(
  uuid, uuid[], text, text, date
) from public, anon, authenticated;
grant execute on function public.admin_update_honor_group(
  uuid, uuid[], text, text, date
) to authenticated;

commit;
