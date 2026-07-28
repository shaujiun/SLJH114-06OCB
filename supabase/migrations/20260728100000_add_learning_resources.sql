-- Learning methods and videos for students, managed by administrators and
-- approved subject teachers. Arbitrary HTML and iframe code are never stored.

begin;

create table if not exists public.learning_resources (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  class_subject_id uuid references public.class_subjects(id) on delete restrict,
  resource_type text not null check (resource_type in ('method', 'video')),
  content_type text not null check (content_type in ('external', 'article', 'video')),
  title text not null check (char_length(btrim(title)) between 1 and 120),
  summary text check (summary is null or char_length(summary) <= 1000),
  article_body text check (article_body is null or char_length(article_body) <= 20000),
  content_url text check (
    content_url is null
    or content_url ~* '^https://'
    or content_url ~* '^http://'
  ),
  source_name text check (source_name is null or char_length(source_name) <= 100),
  source_url text check (
    source_url is null
    or source_url ~* '^https://'
    or source_url ~* '^http://'
  ),
  image_path text,
  image_alt_text text check (image_alt_text is null or char_length(image_alt_text) <= 120),
  published_at timestamptz not null default now(),
  is_pinned boolean not null default false,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  updated_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint learning_resource_content_valid check (
    (
      resource_type = 'method'
      and content_type = 'external'
      and content_url is not null
      and article_body is null
    )
    or (
      resource_type = 'method'
      and content_type = 'article'
      and article_body is not null
      and char_length(btrim(article_body)) > 0
      and source_name is not null
      and char_length(btrim(source_name)) > 0
    )
    or (
      resource_type = 'video'
      and content_type = 'video'
      and content_url is not null
      and article_body is null
    )
  )
);

create index if not exists learning_resources_student_list_idx
  on public.learning_resources (
    class_id,
    resource_type,
    is_active,
    is_pinned desc,
    sort_order,
    published_at desc
  );

create index if not exists learning_resources_creator_idx
  on public.learning_resources (created_by, created_at desc);

drop trigger if exists learning_resources_set_updated_at
  on public.learning_resources;
create trigger learning_resources_set_updated_at
before update on public.learning_resources
for each row execute function public.set_updated_at();

alter table public.learning_resources enable row level security;

create or replace function public.learning_resource_subject_matches(
  target_class_id uuid,
  target_class_subject_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target_class_subject_id is null
    or exists (
      select 1
      from public.class_subjects class_subject
      where class_subject.id = target_class_subject_id
        and class_subject.class_id = target_class_id
        and class_subject.is_active
    );
$$;

revoke all on function public.learning_resource_subject_matches(uuid, uuid)
  from public;
revoke all on function public.learning_resource_subject_matches(uuid, uuid)
  from anon;
grant execute
  on function public.learning_resource_subject_matches(uuid, uuid)
  to authenticated;

drop policy if exists learning_resources_read_allowed
  on public.learning_resources;
create policy learning_resources_read_allowed
on public.learning_resources
for select
to authenticated
using (
  public.contact_book_is_admin()
  or (
    created_by = auth.uid()
    and public.is_approved_user()
  )
  or (
    is_active
    and published_at <= now()
    and public.can_view_class(class_id)
  )
);

drop policy if exists learning_resources_insert_allowed
  on public.learning_resources;
create policy learning_resources_insert_allowed
on public.learning_resources
for insert
to authenticated
with check (
  created_by = auth.uid()
  and updated_by = auth.uid()
  and (
    (
      public.contact_book_is_admin()
      and public.can_manage_class(class_id)
      and public.learning_resource_subject_matches(class_id, class_subject_id)
    )
    or (
      class_subject_id is not null
      and public.can_manage_subject(class_subject_id)
      and public.learning_resource_subject_matches(class_id, class_subject_id)
    )
  )
);

drop policy if exists learning_resources_update_allowed
  on public.learning_resources;
create policy learning_resources_update_allowed
on public.learning_resources
for update
to authenticated
using (
  (
    public.contact_book_is_admin()
    and public.can_manage_class(class_id)
  )
  or (
    created_by = auth.uid()
    and class_subject_id is not null
    and public.can_manage_subject(class_subject_id)
  )
)
with check (
  updated_by = auth.uid()
  and (
    (
      public.contact_book_is_admin()
      and public.can_manage_class(class_id)
      and public.learning_resource_subject_matches(class_id, class_subject_id)
    )
    or (
      created_by = auth.uid()
      and class_subject_id is not null
      and public.can_manage_subject(class_subject_id)
      and public.learning_resource_subject_matches(class_id, class_subject_id)
    )
  )
);

drop policy if exists learning_resources_delete_allowed
  on public.learning_resources;
create policy learning_resources_delete_allowed
on public.learning_resources
for delete
to authenticated
using (
  (
    public.contact_book_is_admin()
    and public.can_manage_class(class_id)
  )
  or (
    created_by = auth.uid()
    and class_subject_id is not null
    and public.can_manage_subject(class_subject_id)
  )
);

revoke all on public.learning_resources from anon;
grant select, insert, update, delete
  on public.learning_resources to authenticated;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'contact-book-learning-resources',
  'contact-book-learning-resources',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists contact_book_learning_images_read
  on storage.objects;
create policy contact_book_learning_images_read
on storage.objects
for select
to authenticated
using (
  bucket_id = 'contact-book-learning-resources'
  and exists (
    select 1
    from public.classes class_row
    where class_row.id::text = (storage.foldername(name))[1]
      and public.can_view_class(class_row.id)
  )
);

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
    join public.contact_book_profiles profile on profile.id = auth.uid()
    where class_row.id::text = (storage.foldername(name))[1]
      and public.can_view_class(class_row.id)
      and profile.user_type in ('admin', 'teacher')
      and profile.approval_status = 'approved'
      and profile.is_active
  )
);

drop policy if exists contact_book_learning_images_update
  on storage.objects;
create policy contact_book_learning_images_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'contact-book-learning-resources'
  and exists (
    select 1
    from public.classes class_row
    where class_row.id::text = (storage.foldername(name))[1]
      and (
        public.can_manage_class(class_row.id)
        or (storage.foldername(name))[2] = auth.uid()::text
      )
  )
)
with check (
  bucket_id = 'contact-book-learning-resources'
  and exists (
    select 1
    from public.classes class_row
    where class_row.id::text = (storage.foldername(name))[1]
      and (
        public.can_manage_class(class_row.id)
        or (storage.foldername(name))[2] = auth.uid()::text
      )
  )
);

drop policy if exists contact_book_learning_images_delete
  on storage.objects;
create policy contact_book_learning_images_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'contact-book-learning-resources'
  and exists (
    select 1
    from public.classes class_row
    where class_row.id::text = (storage.foldername(name))[1]
      and (
        public.can_manage_class(class_row.id)
        or (storage.foldername(name))[2] = auth.uid()::text
      )
  )
);

create or replace function public.save_learning_resource_order(
  p_resource_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_count integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  requested_count := coalesce(array_length(p_resource_ids, 1), 0);
  if requested_count < 1
    or requested_count > 200
    or (
      select count(distinct resource_id)
      from unnest(p_resource_ids) as resource_id
    ) <> requested_count then
    raise exception 'invalid_learning_resource_order';
  end if;

  if (
    select count(*)
    from public.learning_resources resource
    where resource.id = any(p_resource_ids)
      and (
        (
          public.contact_book_is_admin()
          and public.can_manage_class(resource.class_id)
        )
        or (
          resource.created_by = auth.uid()
          and resource.class_subject_id is not null
          and public.can_manage_subject(resource.class_subject_id)
        )
      )
  ) <> requested_count then
    raise exception 'learning_resource_permission_required' using errcode = '42501';
  end if;

  update public.learning_resources resource
  set sort_order = requested.ordinality * 10,
      updated_by = auth.uid(),
      updated_at = now()
  from unnest(p_resource_ids) with ordinality
    as requested(resource_id, ordinality)
  where resource.id = requested.resource_id;

  return jsonb_build_object('updatedCount', requested_count);
end;
$$;

revoke all on function public.save_learning_resource_order(uuid[]) from public;
revoke all on function public.save_learning_resource_order(uuid[]) from anon;
grant execute on function public.save_learning_resource_order(uuid[])
  to authenticated;

commit;
