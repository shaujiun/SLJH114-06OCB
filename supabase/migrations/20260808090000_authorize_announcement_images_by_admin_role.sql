-- Announcement creation is currently an administrator-only interface. Keep
-- Storage authorization independent of class-path parsing, which can reject a
-- valid administrator before the announcements row policy is evaluated.

begin;

create or replace function public.can_manage_announcement_images()
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
      and profile.user_type = 'admin'
      and profile.approval_status = 'approved'
      and profile.is_active
  );
$$;

revoke all on function public.can_manage_announcement_images()
  from public;
revoke all on function public.can_manage_announcement_images()
  from anon;
grant execute on function public.can_manage_announcement_images()
  to authenticated;

drop policy if exists contact_book_announcement_images_insert
  on storage.objects;
create policy contact_book_announcement_images_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'contact-book-announcements'
  and public.can_manage_announcement_images()
);

drop policy if exists contact_book_announcement_images_update
  on storage.objects;
create policy contact_book_announcement_images_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'contact-book-announcements'
  and public.can_manage_announcement_images()
)
with check (
  bucket_id = 'contact-book-announcements'
  and public.can_manage_announcement_images()
);

drop policy if exists contact_book_announcement_images_delete
  on storage.objects;
create policy contact_book_announcement_images_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'contact-book-announcements'
  and public.can_manage_announcement_images()
);

commit;
