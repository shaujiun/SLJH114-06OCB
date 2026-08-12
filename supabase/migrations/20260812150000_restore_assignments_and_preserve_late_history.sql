begin;

create or replace function public.restore_contact_book_assignment(
  p_assignment_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_assignment public.assignments%rowtype;
  recipient_count integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  select assignment.* into target_assignment
  from public.assignments assignment
  where assignment.id = p_assignment_id
  for update;

  if not found then raise exception 'invalid_assignment'; end if;
  if target_assignment.is_active then raise exception 'assignment_already_active'; end if;
  if not public.can_manage_subject(target_assignment.class_subject_id) then
    raise exception 'restore_permission_required' using errcode = '42501';
  end if;

  update public.assignments assignment
  set is_active = true,
      cancelled_at = null,
      updated_at = now()
  where assignment.id = p_assignment_id;

  select count(*) into recipient_count
  from public.assignment_recipients recipient
  where recipient.assignment_id = p_assignment_id;

  return jsonb_build_object(
    'assignmentId', p_assignment_id,
    'restoredAt', now(),
    'recipientCount', recipient_count
  );
end;
$$;

revoke all on function public.restore_contact_book_assignment(uuid)
  from public, anon, authenticated;
grant execute on function public.restore_contact_book_assignment(uuid)
  to authenticated;

create or replace function public.get_my_cancelled_late_assignment_history()
returns table (
  assignment_id uuid,
  due_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select distinct assignment.id, assignment.due_at
  from public.submission_exceptions exception
  join public.assignments assignment on assignment.id = exception.assignment_id
  where auth.uid() is not null
    and exception.student_id = public.current_student_id()
    and exception.counts_as_late
    and not assignment.is_active;
$$;

revoke all on function public.get_my_cancelled_late_assignment_history()
  from public, anon, authenticated;
grant execute on function public.get_my_cancelled_late_assignment_history()
  to authenticated;

commit;
