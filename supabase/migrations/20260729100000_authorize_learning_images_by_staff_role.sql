-- Storage authorization must not depend on parsing the object path. The
-- learning_resources table separately enforces class, subject, creator and
-- administrator permissions when the resource row is saved.

begin;

create or replace function public.can_upload_learning_resource_image()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.contact_book_profiles profile
    where profile.id = auth.uid()
      and profile.user_type in ('admin', 'teacher')
      and profile.approval_status = 'approved'
      and profile.is_active
  );
$$;

revoke all on function public.can_upload_learning_resource_image()
  from public;
revoke all on function public.can_upload_learning_resource_image()
  from anon;
grant execute on function public.can_upload_learning_resource_image()
  to authenticated;

drop policy if exists contact_book_learning_images_insert
  on storage.objects;
create policy contact_book_learning_images_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'contact-book-learning-resources'
  and public.can_upload_learning_resource_image()
);

commit;
