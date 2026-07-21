-- Allow contact-book administrators to create a school subject and enable it
-- for the selected class in one atomic operation.

create or replace function public.admin_add_class_subject(
  p_class_id uuid,
  p_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
  v_school_id uuid;
  v_subject public.subjects%rowtype;
  v_class_subject public.class_subjects%rowtype;
  v_sort_order integer;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  if not public.contact_book_is_admin() then
    raise exception 'permission_denied';
  end if;

  v_name := regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g');
  if char_length(v_name) < 1 or char_length(v_name) > 20 then
    raise exception 'invalid_subject_name';
  end if;

  select ay.school_id
  into v_school_id
  from public.classes c
  join public.academic_years ay on ay.id = c.academic_year_id
  where c.id = p_class_id
    and c.is_active;

  if v_school_id is null then
    raise exception 'invalid_class';
  end if;

  select s.*
  into v_subject
  from public.subjects s
  where s.school_id = v_school_id
    and lower(s.name) = lower(v_name)
  limit 1;

  if v_subject.id is null then
    insert into public.subjects (school_id, code, name)
    values (
      v_school_id,
      'custom_' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12),
      v_name
    )
    returning * into v_subject;
  end if;

  select coalesce(max(cs.sort_order), 0) + 10
  into v_sort_order
  from public.class_subjects cs
  where cs.class_id = p_class_id;

  select cs.*
  into v_class_subject
  from public.class_subjects cs
  where cs.class_id = p_class_id
    and cs.subject_id = v_subject.id;

  if v_class_subject.id is not null and v_class_subject.is_active then
    raise exception 'subject_exists';
  elsif v_class_subject.id is not null then
    update public.class_subjects
    set is_active = true,
        sort_order = v_sort_order
    where id = v_class_subject.id
    returning * into v_class_subject;
  else
    insert into public.class_subjects (class_id, subject_id, sort_order, is_active)
    values (p_class_id, v_subject.id, v_sort_order, true)
    returning * into v_class_subject;
  end if;

  return jsonb_build_object(
    'classSubjectId', v_class_subject.id,
    'subjectId', v_subject.id,
    'code', v_subject.code::text,
    'name', v_subject.name,
    'sortOrder', v_class_subject.sort_order
  );
end;
$$;

revoke all on function public.admin_add_class_subject(uuid, text) from public;
revoke all on function public.admin_add_class_subject(uuid, text) from anon;
grant execute on function public.admin_add_class_subject(uuid, text) to authenticated;
