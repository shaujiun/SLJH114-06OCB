-- Private image storage for the online contact book announcement module.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'contact-book-announcements',
  'contact-book-announcements',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists contact_book_announcement_images_read on storage.objects;
create policy contact_book_announcement_images_read on storage.objects
for select to authenticated
using (
  bucket_id = 'contact-book-announcements'
  and exists (
    select 1
    from public.classes c
    where c.id::text = (storage.foldername(name))[1]
      and public.can_view_class(c.id)
  )
);

drop policy if exists contact_book_announcement_images_insert on storage.objects;
create policy contact_book_announcement_images_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'contact-book-announcements'
  and exists (
    select 1
    from public.classes c
    where c.id::text = (storage.foldername(name))[1]
      and public.can_manage_class(c.id)
  )
);

drop policy if exists contact_book_announcement_images_update on storage.objects;
create policy contact_book_announcement_images_update on storage.objects
for update to authenticated
using (
  bucket_id = 'contact-book-announcements'
  and exists (
    select 1
    from public.classes c
    where c.id::text = (storage.foldername(name))[1]
      and public.can_manage_class(c.id)
  )
)
with check (
  bucket_id = 'contact-book-announcements'
  and exists (
    select 1
    from public.classes c
    where c.id::text = (storage.foldername(name))[1]
      and public.can_manage_class(c.id)
  )
);

drop policy if exists contact_book_announcement_images_delete on storage.objects;
create policy contact_book_announcement_images_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'contact-book-announcements'
  and exists (
    select 1
    from public.classes c
    where c.id::text = (storage.foldername(name))[1]
      and public.can_manage_class(c.id)
  )
);
