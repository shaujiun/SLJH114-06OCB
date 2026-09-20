-- Allow announcements and learning resources to keep an ordered gallery of
-- images while retaining the original single-image columns for rollback
-- compatibility.

begin;

alter table public.announcements
  add column if not exists image_paths text[] not null default array[]::text[],
  add column if not exists image_alt_texts text[] not null default array[]::text[];

update public.announcements
set image_paths = array[image_path],
    image_alt_texts = array[coalesce(nullif(btrim(image_alt_text), ''), title)]
where image_path is not null
  and cardinality(image_paths) = 0;

alter table public.announcements
  drop constraint if exists announcements_image_count_check,
  drop constraint if exists announcements_image_alt_count_check;

alter table public.announcements
  add constraint announcements_image_count_check
    check (cardinality(image_paths) <= 10),
  add constraint announcements_image_alt_count_check
    check (cardinality(image_paths) = cardinality(image_alt_texts));

alter table public.learning_resources
  add column if not exists image_paths text[] not null default array[]::text[],
  add column if not exists image_alt_texts text[] not null default array[]::text[];

update public.learning_resources
set image_paths = array[image_path],
    image_alt_texts = array[coalesce(nullif(btrim(image_alt_text), ''), title)]
where image_path is not null
  and cardinality(image_paths) = 0;

alter table public.learning_resources
  drop constraint if exists learning_resources_image_count_check,
  drop constraint if exists learning_resources_image_alt_count_check;

alter table public.learning_resources
  add constraint learning_resources_image_count_check
    check (cardinality(image_paths) <= 10),
  add constraint learning_resources_image_alt_count_check
    check (cardinality(image_paths) = cardinality(image_alt_texts));

commit;
