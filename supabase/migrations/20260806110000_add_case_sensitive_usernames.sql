-- Preserve the username spelling shown to users while keeping the shared Auth
-- email alias case-insensitive. Login code compares the submitted username with
-- the exact value stored in these profile tables.

alter table public.contact_book_profiles
  drop constraint if exists contact_book_profiles_username_key;

alter table public.contact_book_profiles
  alter column username type text using username::text;

create unique index if not exists contact_book_profiles_username_lower_unique
  on public.contact_book_profiles (lower(username));

do $$
begin
  if to_regclass('public.profiles') is not null then
    alter table public.profiles
      drop constraint if exists profiles_username_key;

    create unique index if not exists profiles_username_lower_unique
      on public.profiles (lower(username));
  end if;
end
$$;

update public.contact_book_profiles
set username = 'Chung'
where lower(username) = 'chung';

do $$
begin
  if to_regclass('public.profiles') is not null then
    update public.profiles
    set username = 'Chung'
    where lower(username) = 'chung';
  end if;
end
$$;

update auth.users
set raw_user_meta_data = jsonb_set(
  coalesce(raw_user_meta_data, '{}'::jsonb),
  '{username}',
  to_jsonb('Chung'::text),
  true
)
where lower(email) = 'chung@vocab-explorer.app';
