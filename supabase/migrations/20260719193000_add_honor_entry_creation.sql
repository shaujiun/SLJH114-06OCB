-- Create honor entries from verified class and student data so the public
-- display-name snapshot cannot be supplied or altered by the browser.

create or replace function public.admin_create_honor_entry(
  p_class_id uuid,
  p_student_id uuid,
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
  v_student public.students%rowtype;
  v_entry public.honor_entries%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  if not public.can_manage_class(p_class_id) then
    raise exception 'permission_denied';
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

  select s.*
  into v_student
  from public.students s
  where s.id = p_student_id
    and s.class_id = p_class_id
    and s.is_active;

  if v_student.id is null then
    raise exception 'invalid_class_student';
  end if;

  insert into public.honor_entries (
    class_id,
    student_id,
    student_display_name,
    title,
    description,
    awarded_on,
    created_by,
    is_visible
  )
  values (
    p_class_id,
    v_student.id,
    v_student.full_name,
    v_title,
    nullif(v_description, ''),
    p_awarded_on,
    auth.uid(),
    true
  )
  returning * into v_entry;

  return jsonb_build_object(
    'id', v_entry.id,
    'studentId', v_entry.student_id,
    'studentDisplayName', v_entry.student_display_name,
    'title', v_entry.title,
    'description', v_entry.description,
    'awardedOn', v_entry.awarded_on,
    'isVisible', v_entry.is_visible
  );
end;
$$;

revoke all on function public.admin_create_honor_entry(uuid, uuid, text, text, date) from public;
revoke all on function public.admin_create_honor_entry(uuid, uuid, text, text, date) from anon;
grant execute on function public.admin_create_honor_entry(uuid, uuid, text, text, date) to authenticated;

create or replace function public.admin_set_honor_visibility(
  p_honor_id uuid,
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

  select h.class_id into v_class_id
  from public.honor_entries h
  where h.id = p_honor_id;

  if v_class_id is null then
    raise exception 'invalid_honor_entry';
  end if;
  if not public.can_manage_class(v_class_id) then
    raise exception 'permission_denied';
  end if;

  update public.honor_entries
  set is_visible = p_is_visible
  where id = p_honor_id;
end;
$$;

revoke all on function public.admin_set_honor_visibility(uuid, boolean) from public;
revoke all on function public.admin_set_honor_visibility(uuid, boolean) from anon;
grant execute on function public.admin_set_honor_visibility(uuid, boolean) to authenticated;
