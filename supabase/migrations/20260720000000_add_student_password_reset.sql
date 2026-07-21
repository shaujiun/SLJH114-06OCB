-- Allow an administrator to issue a one-time reset code while the student
-- chooses the new password without revealing it to the administrator.

begin;

create table if not exists public.student_password_reset_codes (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  code_hash text not null,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

create unique index if not exists one_unused_password_reset_code_per_student
  on public.student_password_reset_codes(student_id)
  where used_at is null;

alter table public.student_password_reset_codes enable row level security;

drop policy if exists password_reset_codes_admin_all
  on public.student_password_reset_codes;
create policy password_reset_codes_admin_all on public.student_password_reset_codes
for all to authenticated
using (
  exists (
    select 1
    from public.students student
    where student.id = student_id
      and public.can_manage_class(student.class_id)
  )
)
with check (
  exists (
    select 1
    from public.students student
    where student.id = student_id
      and public.can_manage_class(student.class_id)
  )
);

create or replace function public.admin_replace_student_password_reset(
  p_student_id uuid,
  p_code_hash text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_student public.students%rowtype;
  created_reset public.student_password_reset_codes%rowtype;
begin
  if not public.contact_book_is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;
  if p_code_hash is null or length(trim(p_code_hash)) < 32
    or p_expires_at <= now() then
    raise exception 'invalid_password_reset_data';
  end if;

  select * into target_student
  from public.students student
  where student.id = p_student_id and student.is_active
  for update;

  if not found or target_student.profile_id is null then
    raise exception 'student_not_activated';
  end if;
  if not exists (
    select 1
    from public.contact_book_profiles profile
    where profile.id = target_student.profile_id
      and profile.user_type = 'student'
      and profile.approval_status = 'approved'
      and profile.is_active
  ) then
    raise exception 'student_account_unavailable';
  end if;

  update public.student_password_reset_codes reset_code
  set used_at = now()
  where reset_code.student_id = p_student_id
    and reset_code.used_at is null;

  insert into public.student_password_reset_codes (
    student_id,
    code_hash,
    expires_at,
    created_by
  ) values (
    p_student_id,
    p_code_hash,
    p_expires_at,
    auth.uid()
  ) returning * into created_reset;

  return jsonb_build_object(
    'studentId', target_student.id,
    'studentIdCode', target_student.student_id_code,
    'expiresAt', created_reset.expires_at
  );
end;
$$;

revoke all on function public.admin_replace_student_password_reset(
  uuid, text, timestamptz
) from public, anon, authenticated;
grant execute on function public.admin_replace_student_password_reset(
  uuid, text, timestamptz
) to authenticated;

create or replace function public.consume_student_password_reset(
  p_student_id_code text,
  p_code_hash text
)
returns table (student_id uuid, profile_id uuid, display_name text)
language plpgsql
security definer
set search_path = public
as $$
declare
  target_student public.students%rowtype;
  target_profile public.contact_book_profiles%rowtype;
  target_code public.student_password_reset_codes%rowtype;
begin
  select * into target_student
  from public.students student
  where student.student_id_code = p_student_id_code
    and student.is_active
  for update;

  if not found or target_student.profile_id is null then
    raise exception 'invalid_password_reset';
  end if;

  select * into target_profile
  from public.contact_book_profiles profile
  where profile.id = target_student.profile_id
    and profile.user_type = 'student'
    and profile.approval_status = 'approved'
    and profile.is_active;
  if not found then raise exception 'invalid_password_reset'; end if;

  select * into target_code
  from public.student_password_reset_codes reset_code
  where reset_code.student_id = target_student.id
    and reset_code.code_hash = p_code_hash
    and reset_code.used_at is null
    and reset_code.expires_at > now()
  for update;
  if not found then raise exception 'invalid_password_reset'; end if;

  update public.student_password_reset_codes
  set used_at = now()
  where id = target_code.id;

  return query select target_student.id, target_profile.id, target_student.full_name;
end;
$$;

revoke all on function public.consume_student_password_reset(text, text)
  from public, anon, authenticated;
grant execute on function public.consume_student_password_reset(text, text)
  to service_role;

commit;
