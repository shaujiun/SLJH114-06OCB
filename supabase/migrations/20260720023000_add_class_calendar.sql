-- Independent class calendar. Students and teachers can read active events;
-- the homeroom administrator can create, edit, deactivate, and restore them.

begin;

create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  title text not null,
  description text,
  location text,
  category text not null default 'class_activity'
    check (category in ('class_activity', 'school_activity', 'exam', 'holiday', 'other')),
  starts_on date not null,
  ends_on date not null,
  is_all_day boolean not null default true,
  start_time time,
  end_time time,
  is_active boolean not null default true,
  created_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  last_updated_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint calendar_event_title_valid check (char_length(btrim(title)) between 1 and 80),
  constraint calendar_event_description_valid check (char_length(coalesce(description, '')) <= 2000),
  constraint calendar_event_location_valid check (char_length(coalesce(location, '')) <= 100),
  constraint calendar_event_dates_valid check (ends_on >= starts_on),
  constraint calendar_event_times_valid check (
    (is_all_day and start_time is null and end_time is null)
    or (
      not is_all_day
      and start_time is not null
      and end_time is not null
      and (ends_on > starts_on or end_time > start_time)
    )
  )
);

create index if not exists calendar_events_class_dates_idx
  on public.calendar_events(class_id, starts_on, ends_on);

drop trigger if exists calendar_events_set_updated_at on public.calendar_events;
create trigger calendar_events_set_updated_at
before update on public.calendar_events
for each row execute function public.contact_book_set_updated_at();

alter table public.calendar_events enable row level security;

drop policy if exists calendar_events_read_allowed on public.calendar_events;
create policy calendar_events_read_allowed on public.calendar_events
for select to authenticated using (
  public.can_manage_class(class_id)
  or (is_active and public.can_view_class(class_id))
);

create or replace function public.admin_save_calendar_event(
  p_event_id uuid,
  p_class_id uuid,
  p_title text,
  p_description text,
  p_location text,
  p_category text,
  p_starts_on date,
  p_ends_on date,
  p_is_all_day boolean,
  p_start_time time,
  p_end_time time
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_title text;
  normalized_description text;
  normalized_location text;
  saved_event public.calendar_events%rowtype;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.can_manage_class(p_class_id) then raise exception 'permission_denied'; end if;

  normalized_title := regexp_replace(btrim(coalesce(p_title, '')), '\s+', ' ', 'g');
  normalized_description := btrim(coalesce(p_description, ''));
  normalized_location := regexp_replace(btrim(coalesce(p_location, '')), '\s+', ' ', 'g');

  if char_length(normalized_title) < 1 or char_length(normalized_title) > 80
    or char_length(normalized_description) > 2000
    or char_length(normalized_location) > 100
    or p_category not in ('class_activity', 'school_activity', 'exam', 'holiday', 'other')
    or p_starts_on is null or p_ends_on is null or p_ends_on < p_starts_on
    or p_is_all_day is null
    or (
      p_is_all_day = false and (
        p_start_time is null or p_end_time is null
        or (p_ends_on = p_starts_on and p_end_time <= p_start_time)
      )
    ) then
    raise exception 'invalid_calendar_event';
  end if;

  if p_event_id is null then
    insert into public.calendar_events (
      class_id, title, description, location, category, starts_on, ends_on,
      is_all_day, start_time, end_time, created_by, last_updated_by
    ) values (
      p_class_id,
      normalized_title,
      nullif(normalized_description, ''),
      nullif(normalized_location, ''),
      p_category,
      p_starts_on,
      p_ends_on,
      p_is_all_day,
      case when p_is_all_day then null else p_start_time end,
      case when p_is_all_day then null else p_end_time end,
      auth.uid(),
      auth.uid()
    ) returning * into saved_event;
  else
    update public.calendar_events event
    set title = normalized_title,
        description = nullif(normalized_description, ''),
        location = nullif(normalized_location, ''),
        category = p_category,
        starts_on = p_starts_on,
        ends_on = p_ends_on,
        is_all_day = p_is_all_day,
        start_time = case when p_is_all_day then null else p_start_time end,
        end_time = case when p_is_all_day then null else p_end_time end,
        last_updated_by = auth.uid()
    where event.id = p_event_id
      and event.class_id = p_class_id
    returning * into saved_event;

    if saved_event.id is null then raise exception 'invalid_calendar_event_id'; end if;
  end if;

  return jsonb_build_object(
    'id', saved_event.id,
    'title', saved_event.title,
    'startsOn', saved_event.starts_on,
    'endsOn', saved_event.ends_on,
    'isActive', saved_event.is_active
  );
end;
$$;

revoke all on function public.admin_save_calendar_event(
  uuid, uuid, text, text, text, text, date, date, boolean, time, time
) from public, anon, authenticated;
grant execute on function public.admin_save_calendar_event(
  uuid, uuid, text, text, text, text, date, date, boolean, time, time
) to authenticated;

create or replace function public.admin_set_calendar_event_active(
  p_event_id uuid,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_event public.calendar_events%rowtype;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_is_active is null then raise exception 'invalid_calendar_event_status'; end if;

  select event.* into target_event
  from public.calendar_events event
  where event.id = p_event_id
  for update;

  if not found then raise exception 'invalid_calendar_event_id'; end if;
  if not public.can_manage_class(target_event.class_id) then raise exception 'permission_denied'; end if;

  update public.calendar_events event
  set is_active = p_is_active,
      last_updated_by = auth.uid()
  where event.id = p_event_id;

  return jsonb_build_object('id', p_event_id, 'isActive', p_is_active);
end;
$$;

revoke all on function public.admin_set_calendar_event_active(uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.admin_set_calendar_event_active(uuid, boolean)
  to authenticated;

commit;
