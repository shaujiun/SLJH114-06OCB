-- Keep learning-resource image uploads consistent with the established
-- announcement-image policy. Approval and class access are already enforced
-- by can_view_class(); the resource row insert separately enforces subject
-- ownership and teacher permissions.

begin;

drop policy if exists contact_book_learning_images_insert
  on storage.objects;
create policy contact_book_learning_images_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'contact-book-learning-resources'
  and (storage.foldername(name))[2] = auth.uid()::text
  and exists (
    select 1
    from public.classes class_row
    where class_row.id::text = (storage.foldername(name))[1]
      and public.can_view_class(class_row.id)
  )
);

commit;
