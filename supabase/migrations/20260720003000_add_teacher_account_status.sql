-- Let the contact-book administrator suspend and restore approved teachers
-- while preserving their subject assignments and an audit trail.

begin;

create table if not exists public.teacher_account_status_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.contact_book_profiles(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  was_active boolean not null,
  is_active boolean not null,
  changed_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint teacher_status_must_change check (was_active <> is_active)
);

create index if not exists teacher_account_status_events_profile_idx
  on public.teacher_account_status_events(profile_id, created_at desc);

alter table public.teacher_account_status_events enable row level security;

drop policy if exists teacher_status_events_admin_read
  on public.teacher_account_status_events;
create policy teacher_status_events_admin_read on public.teacher_account_status_events
for select to authenticated
using (public.can_manage_class(class_id));

create or replace function public.admin_set_teacher_active(
  p_profile_id uuid,
  p_class_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_profile public.contact_book_profiles%rowtype;
begin
  if not public.contact_book_is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;
  if not public.can_manage_class(p_class_id) then
    raise exception 'class_permission_required' using errcode = '42501';
  end if;

  select * into target_profile
  from public.contact_book_profiles profile
  where profile.id = p_profile_id
    and profile.user_type = 'teacher'
    and profile.approval_status = 'approved'
  for update;
  if not found then raise exception 'invalid_approved_teacher'; end if;

  if not exists (
    select 1
    from public.class_staff_assignments assignment
    where assignment.class_id = p_class_id
      and assignment.profile_id = p_profile_id
      and assignment.role = 'subject_teacher'
      and assignment.ends_on is null
  ) then
    raise exception 'teacher_not_assigned_to_class';
  end if;

  if target_profile.is_active is distinct from p_is_active then
    update public.contact_book_profiles
    set is_active = p_is_active,
        updated_at = now()
    where id = p_profile_id;

    insert into public.teacher_account_status_events (
      profile_id,
      class_id,
      was_active,
      is_active,
      changed_by
    ) values (
      p_profile_id,
      p_class_id,
      target_profile.is_active,
      p_is_active,
      auth.uid()
    );
  end if;

  return jsonb_build_object(
    'profileId', target_profile.id,
    'displayName', target_profile.display_name,
    'isActive', p_is_active
  );
end;
$$;

revoke all on function public.admin_set_teacher_active(uuid, uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.admin_set_teacher_active(uuid, uuid, boolean)
  to authenticated;

commit;
