-- The Storage API already records the authenticated owner of each object.
-- Do not duplicate that check by parsing the second path segment: the Storage
-- insert request can reject otherwise valid administrators before the
-- learning_resources row-level policy has a chance to run.

begin;

drop policy if exists contact_book_learning_images_insert
  on storage.objects;
create policy contact_book_learning_images_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'contact-book-learning-resources'
  and exists (
    select 1
    from public.classes class_row
    where class_row.id::text = (storage.foldername(name))[1]
      and public.can_view_class(class_row.id)
  )
);

commit;
