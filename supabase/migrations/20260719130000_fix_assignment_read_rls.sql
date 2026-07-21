begin;

create or replace function public.is_current_student_assignment_recipient(
  target_assignment_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.assignment_recipients ar
    where ar.assignment_id = target_assignment_id
      and ar.student_id = public.current_student_id()
  );
$$;

create or replace function public.can_read_assignment_recipients_as_staff(
  target_assignment_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.assignments a
    where a.id = target_assignment_id
      and public.can_publish_subject(a.class_subject_id)
  );
$$;

revoke all on function public.is_current_student_assignment_recipient(uuid)
  from public, anon, authenticated;
grant execute on function public.is_current_student_assignment_recipient(uuid)
  to authenticated;

revoke all on function public.can_read_assignment_recipients_as_staff(uuid)
  from public, anon, authenticated;
grant execute on function public.can_read_assignment_recipients_as_staff(uuid)
  to authenticated;

drop policy if exists assignments_read_allowed on public.assignments;
create policy assignments_read_allowed on public.assignments
for select to authenticated using (
  public.can_publish_subject(class_subject_id)
  or (is_active and public.is_current_student_assignment_recipient(id))
);

drop policy if exists recipients_read_allowed on public.assignment_recipients;
create policy recipients_read_allowed on public.assignment_recipients
for select to authenticated using (
  public.is_student_self(student_id)
  or public.can_read_assignment_recipients_as_staff(assignment_id)
);

commit;
