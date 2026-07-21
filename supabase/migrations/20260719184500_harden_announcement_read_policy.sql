-- A student may only acknowledge an active, unexpired announcement belonging
-- to the same class as that student.

drop policy if exists announcement_reads_student_insert on public.announcement_reads;
create policy announcement_reads_student_insert on public.announcement_reads
for insert to authenticated
with check (
  public.is_student_self(student_id)
  and exists (
    select 1
    from public.announcements a
    join public.students s on s.id = student_id
    where a.id = announcement_id
      and a.class_id = s.class_id
      and a.is_active
      and (a.expires_at is null or a.expires_at > now())
  )
);
