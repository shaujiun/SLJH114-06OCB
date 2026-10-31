-- 學習地圖教材庫：管理者上傳，僅已核准的登入學生可閱讀已發布內容。

create or replace function public.can_manage_learning_maps()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.contact_book_is_admin();
$$;

revoke all on function public.can_manage_learning_maps() from public;
revoke all on function public.can_manage_learning_maps() from anon;
grant execute on function public.can_manage_learning_maps() to authenticated;

create table if not exists public.learning_maps (
  id uuid primary key default gen_random_uuid(),
  map_code text not null unique,
  subject_code text not null check (subject_code in ('history', 'geography', 'civics')),
  grade_level smallint not null check (grade_level between 7 and 9),
  semester smallint not null check (semester in (1, 2)),
  chapter_no smallint not null check (chapter_no between 1 and 30),
  title text not null default '',
  description text not null default '',
  creator_name text not null default '',
  source_name text not null default '',
  source_url text not null default '',
  usage_note text not null default '',
  storage_path text not null default '',
  original_file_name text not null default '',
  mime_type text not null default '',
  display_order integer not null default 0,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  published_at timestamptz,
  created_by uuid references public.contact_book_profiles(id) on delete set null,
  updated_by uuid references public.contact_book_profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint learning_maps_published_complete check (
    status <> 'published' or (
      length(trim(title)) > 0
      and length(trim(creator_name)) > 0
      and length(trim(source_url)) > 0
      and length(trim(storage_path)) > 0
      and length(trim(mime_type)) > 0
    )
  )
);

create index if not exists learning_maps_subject_order_idx
  on public.learning_maps(subject_code, grade_level, semester, chapter_no, display_order);

alter table public.learning_maps enable row level security;

drop policy if exists learning_maps_admin_all on public.learning_maps;
create policy learning_maps_admin_all on public.learning_maps
for all to authenticated
using (public.can_manage_learning_maps())
with check (public.can_manage_learning_maps());

drop policy if exists learning_maps_student_select on public.learning_maps;
create policy learning_maps_student_select on public.learning_maps
for select to authenticated
using (status = 'published' and public.is_active_learning_student());

revoke all on public.learning_maps from public, anon;
grant select, insert, update, delete on public.learning_maps to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'learning-map-assets',
  'learning-map-assets',
  false,
  15728640,
  array['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists learning_map_assets_authorized_read on storage.objects;
create policy learning_map_assets_authorized_read on storage.objects
for select to authenticated
using (
  bucket_id = 'learning-map-assets'
  and (
    public.can_manage_learning_maps()
    or (
      public.is_active_learning_student()
      and exists (
        select 1
        from public.learning_maps learning_map
        where learning_map.storage_path = name
          and learning_map.status = 'published'
      )
    )
  )
);

drop policy if exists learning_map_assets_manager_insert on storage.objects;
create policy learning_map_assets_manager_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'learning-map-assets' and public.can_manage_learning_maps());

drop policy if exists learning_map_assets_manager_update on storage.objects;
create policy learning_map_assets_manager_update on storage.objects
for update to authenticated
using (bucket_id = 'learning-map-assets' and public.can_manage_learning_maps())
with check (bucket_id = 'learning-map-assets' and public.can_manage_learning_maps());

drop policy if exists learning_map_assets_manager_delete on storage.objects;
create policy learning_map_assets_manager_delete on storage.objects
for delete to authenticated
using (bucket_id = 'learning-map-assets' and public.can_manage_learning_maps());

insert into public.learning_maps (
  map_code, subject_code, grade_level, semester, chapter_no, title,
  description, creator_name, source_name, source_url, usage_note,
  display_order, status
)
values
  (
    'geography-8-1-ch03-flipping-geography', 'geography', 8, 1, 3,
    '中國的工業', '八年級上學期地理 CH3 心智地圖。',
    '翻轉地理教室', '翻轉地理教室',
    'https://eduforeveryone123.wixsite.com/flippinggeography',
    '製作老師透過 LINE 官方帳號提供自由下載使用；本站僅供已核准學生登入閱讀。',
    8030, 'draft'
  ),
  (
    'geography-8-1-ch04-flipping-geography', 'geography', 8, 1, 4,
    '中國的經濟發展與全球關連', '八年級上學期地理 CH4 心智地圖。',
    '翻轉地理教室', '翻轉地理教室',
    'https://eduforeveryone123.wixsite.com/flippinggeography',
    '製作老師透過 LINE 官方帳號提供自由下載使用；本站僅供已核准學生登入閱讀。',
    8040, 'draft'
  )
on conflict (map_code) do nothing;
