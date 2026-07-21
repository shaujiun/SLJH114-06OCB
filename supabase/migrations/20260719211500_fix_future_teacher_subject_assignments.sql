-- The school year can start after the administration setup date. Keep an
-- already scheduled assignment instead of attempting to insert it again.

create or replace function public.admin_update_teacher_subjects(
  p_profile_id uuid,
  p_class_id uuid,
  p_class_subject_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subject_ids uuid[];
  v_valid_subject_count integer;
  v_start_date date;
  v_profile public.contact_book_profiles%rowtype;
begin
  if not public.contact_book_is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  select array_agg(distinct selected_id)
  into v_subject_ids
  from unnest(coalesce(p_class_subject_ids, array[]::uuid[])) as selected(selected_id);

  if coalesce(cardinality(v_subject_ids), 0) < 1 then
    raise exception 'subject_required';
  end if;

  select p.*
  into v_profile
  from public.contact_book_profiles p
  where p.id = p_profile_id
    and p.user_type = 'teacher'
    and p.approval_status = 'approved'
    and p.is_active;

  if v_profile.id is null then
    raise exception 'invalid_approved_teacher';
  end if;

  select count(*)
  into v_valid_subject_count
  from public.class_subjects cs
  where cs.id = any(v_subject_ids)
    and cs.class_id = p_class_id
    and cs.is_active;

  if v_valid_subject_count <> cardinality(v_subject_ids) then
    raise exception 'invalid_class_subjects';
  end if;

  select greatest(current_date, ay.starts_on)
  into v_start_date
  from public.classes c
  join public.academic_years ay on ay.id = c.academic_year_id
  where c.id = p_class_id
    and c.is_active;

  if v_start_date is null then
    raise exception 'invalid_class';
  end if;

  delete from public.class_staff_assignments csa
  where csa.class_id = p_class_id
    and csa.profile_id = p_profile_id
    and csa.role = 'subject_teacher'
    and csa.ends_on is null
    and csa.starts_on >= current_date
    and not (csa.class_subject_id = any(v_subject_ids));

  update public.class_staff_assignments csa
  set ends_on = current_date - 1
  where csa.class_id = p_class_id
    and csa.profile_id = p_profile_id
    and csa.role = 'subject_teacher'
    and csa.ends_on is null
    and csa.starts_on < current_date
    and not (csa.class_subject_id = any(v_subject_ids));

  insert into public.class_staff_assignments (
    class_id,
    profile_id,
    role,
    class_subject_id,
    starts_on,
    created_by
  )
  select
    p_class_id,
    p_profile_id,
    'subject_teacher',
    requested.id,
    v_start_date,
    auth.uid()
  from unnest(v_subject_ids) as requested(id)
  where not exists (
    select 1
    from public.class_staff_assignments active_assignment
    where active_assignment.class_id = p_class_id
      and active_assignment.profile_id = p_profile_id
      and active_assignment.role = 'subject_teacher'
      and active_assignment.class_subject_id = requested.id
      and active_assignment.ends_on is null
  );

  return jsonb_build_object(
    'profileId', v_profile.id,
    'displayName', v_profile.display_name,
    'assignedSubjectCount', cardinality(v_subject_ids)
  );
end;
$$;

revoke all on function public.admin_update_teacher_subjects(uuid, uuid, uuid[]) from public;
revoke all on function public.admin_update_teacher_subjects(uuid, uuid, uuid[]) from anon;
grant execute on function public.admin_update_teacher_subjects(uuid, uuid, uuid[]) to authenticated;
