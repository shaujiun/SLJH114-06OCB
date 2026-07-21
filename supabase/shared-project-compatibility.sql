-- 英文單字測驗與線上聯絡簿共用同一個 Supabase 專案。
-- 英文單字系統原有的 auth.users 觸發器只應建立單字系統 profile，
-- 僅標記為 vocab 的共用帳號會建立英文 profiles；
-- 聯絡簿角色與核准狀態另由 public.contact_book_profiles 管理。
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.raw_user_meta_data->>'app_scope', 'vocab') <> 'vocab' then
    return new;
  end if;

  insert into public.profiles (id, username, role, level_book, level_lesson)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    'student',
    'B1',
    'L1'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;
