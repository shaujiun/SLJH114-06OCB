-- Complete the remaining first-version administration actions:
-- delete grouped honors, cancel published assignments, and manage class subjects.

begin;

create or replace function public.admin_delete_honor_group(
  p_honor_group_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_class_id uuid;
  deleted_count integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  select entry.class_id into target_class_id
  from public.honor_entries entry
  where entry.honor_group_id = p_honor_group_id
  limit 1;

  if target_class_id is null then raise exception 'invalid_honor_entry'; end if;
  if not public.can_manage_class(target_class_id) then raise exception 'permission_denied'; end if;

  delete from public.honor_entries entry
  where entry.honor_group_id = p_honor_group_id;
  get diagnostics deleted_count = row_count;

  return jsonb_build_object(
    'honorGroupId', p_honor_group_id,
    'deletedCount', deleted_count
  );
end;
$$;

revoke all on function public.admin_delete_honor_group(uuid)
  from public, anon, authenticated;
grant execute on function public.admin_delete_honor_group(uuid)
  to authenticated;

create or replace function public.cancel_contact_book_assignment(
  p_assignment_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_assignment public.assignments%rowtype;
  waived_count integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  select assignment.* into target_assignment
  from public.assignments assignment
  where assignment.id = p_assignment_id
  for update;

  if not found then raise exception 'invalid_assignment'; end if;
  if not target_assignment.is_active then raise exception 'assignment_already_cancelled'; end if;
  if not public.can_manage_subject(target_assignment.class_subject_id) then
    raise exception 'cancel_permission_required' using errcode = '42501';
  end if;

  update public.assignments assignment
  set is_active = false,
      cancelled_at = now(),
      updated_at = now()
  where assignment.id = p_assignment_id;

  update public.submission_exceptions exception
  set workflow_state = 'waived',
      counts_as_missing = false,
      counts_as_late = false,
      last_updated_by = auth.uid(),
      updated_at = now()
  where exception.assignment_id = p_assignment_id
    and exception.workflow_state = 'open';
  get diagnostics waived_count = row_count;

  return jsonb_build_object(
    'assignmentId', p_assignment_id,
    'cancelledAt', now(),
    'waivedExceptionCount', waived_count
  );
end;
$$;

revoke all on function public.cancel_contact_book_assignment(uuid)
  from public, anon, authenticated;
grant execute on function public.cancel_contact_book_assignment(uuid)
  to authenticated;

create or replace function public.admin_update_class_subjects(
  p_class_id uuid,
  p_subjects jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_count integer;
  unique_count integer;
  active_count integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.contact_book_is_admin() or not public.can_manage_class(p_class_id) then
    raise exception 'permission_denied';
  end if;
  if jsonb_typeof(coalesce(p_subjects, '[]'::jsonb)) <> 'array' then
    raise exception 'invalid_subject_settings';
  end if;

  select count(*), count(distinct item.class_subject_id),
         count(*) filter (where item.is_active)
  into requested_count, unique_count, active_count
  from jsonb_to_recordset(coalesce(p_subjects, '[]'::jsonb))
    as item(class_subject_id uuid, is_active boolean, sort_order integer);

  if requested_count < 1 or requested_count <> unique_count or active_count < 1
    or exists (
      select 1
      from jsonb_to_recordset(p_subjects)
        as item(class_subject_id uuid, is_active boolean, sort_order integer)
      where item.class_subject_id is null
        or item.is_active is null
        or item.sort_order is null
        or item.sort_order < 0
        or not exists (
          select 1 from public.class_subjects class_subject
          where class_subject.id = item.class_subject_id
            and class_subject.class_id = p_class_id
        )
    ) then
    raise exception 'invalid_subject_settings';
  end if;

  update public.class_subjects class_subject
  set is_active = item.is_active,
      sort_order = item.sort_order
  from jsonb_to_recordset(p_subjects)
    as item(class_subject_id uuid, is_active boolean, sort_order integer)
  where class_subject.id = item.class_subject_id
    and class_subject.class_id = p_class_id;

  return jsonb_build_object(
    'classId', p_class_id,
    'subjectCount', requested_count,
    'activeCount', active_count
  );
end;
$$;

revoke all on function public.admin_update_class_subjects(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.admin_update_class_subjects(uuid, jsonb)
  to authenticated;

commit;
