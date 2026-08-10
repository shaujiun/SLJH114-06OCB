-- Keep private announcement and learning-resource images class-scoped while
-- moving path parsing out of storage.objects RLS expressions.

begin;

create or replace function public.can_read_contact_book_media(object_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when split_part(coalesce(object_name, ''), '/', 1)
      ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
    then public.can_view_class(split_part(object_name, '/', 1)::uuid)
    else false
  end;
$$;

revoke all on function public.can_read_contact_book_media(text) from public;
revoke all on function public.can_read_contact_book_media(text) from anon;
grant execute on function public.can_read_contact_book_media(text) to authenticated;

drop policy if exists contact_book_announcement_images_read on storage.objects;
create policy contact_book_announcement_images_read
on storage.objects
for select
to authenticated
using (
  bucket_id = 'contact-book-announcements'
  and public.can_read_contact_book_media(name)
);

drop policy if exists contact_book_learning_images_read on storage.objects;
create policy contact_book_learning_images_read
on storage.objects
for select
to authenticated
using (
  bucket_id = 'contact-book-learning-resources'
  and public.can_read_contact_book_media(name)
);

commit;
