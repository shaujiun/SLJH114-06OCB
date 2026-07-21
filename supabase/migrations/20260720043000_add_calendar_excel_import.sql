-- Auditable Excel calendar imports with office colors and duplicate protection.

begin;

alter table public.calendar_events
  add column if not exists source_office text,
  add column if not exists source_audience text,
  add column if not exists source_file_name text,
  add column if not exists source_sheet text,
  add column if not exists source_row integer,
  add column if not exists source_key text;

alter table public.calendar_events
  drop constraint if exists calendar_event_source_office_valid,
  add constraint calendar_event_source_office_valid
    check (char_length(coalesce(source_office, '')) <= 80),
  drop constraint if exists calendar_event_source_audience_valid,
  add constraint calendar_event_source_audience_valid
    check (char_length(coalesce(source_audience, '')) <= 120),
  drop constraint if exists calendar_event_source_file_name_valid,
  add constraint calendar_event_source_file_name_valid
    check (char_length(coalesce(source_file_name, '')) <= 255),
  drop constraint if exists calendar_event_source_sheet_valid,
  add constraint calendar_event_source_sheet_valid
    check (char_length(coalesce(source_sheet, '')) <= 80),
  drop constraint if exists calendar_event_source_row_valid,
  add constraint calendar_event_source_row_valid
    check (source_row is null or source_row > 0),
  drop constraint if exists calendar_event_source_key_valid,
  add constraint calendar_event_source_key_valid
    check (source_key is null or char_length(source_key) = 32);

create unique index if not exists calendar_events_import_source_key_idx
  on public.calendar_events(class_id, source_key)
  where source_key is not null;

create or replace function public.admin_import_calendar_events(
  p_class_id uuid,
  p_source_file_name text,
  p_events jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  normalized_title text;
  normalized_description text;
  normalized_location text;
  normalized_office text;
  normalized_audience text;
  normalized_sheet text;
  normalized_source_file text;
  event_category text;
  event_starts_on date;
  event_ends_on date;
  event_is_all_day boolean;
  event_start_time time;
  event_end_time time;
  event_source_row integer;
  event_source_key text;
  affected_rows integer;
  imported_count integer := 0;
  skipped_count integer := 0;
  first_date date := null;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not public.can_manage_class(p_class_id) then raise exception 'permission_denied'; end if;
  if jsonb_typeof(p_events) <> 'array'
    or jsonb_array_length(p_events) < 1
    or jsonb_array_length(p_events) > 500 then
    raise exception 'invalid_import_events';
  end if;

  normalized_source_file := regexp_replace(btrim(coalesce(p_source_file_name, '')), '\s+', ' ', 'g');
  if char_length(normalized_source_file) < 1 or char_length(normalized_source_file) > 255 then
    raise exception 'invalid_import_source_file';
  end if;

  for item in select value from jsonb_array_elements(p_events)
  loop
    begin
      normalized_title := regexp_replace(btrim(coalesce(item->>'title', '')), '\s+', ' ', 'g');
      normalized_description := btrim(coalesce(item->>'description', ''));
      normalized_location := regexp_replace(btrim(coalesce(item->>'location', '')), '\s+', ' ', 'g');
      normalized_office := regexp_replace(btrim(coalesce(item->>'sourceOffice', '')), '\s+', ' ', 'g');
      normalized_audience := regexp_replace(btrim(coalesce(item->>'sourceAudience', '')), '\s+', ' ', 'g');
      normalized_sheet := regexp_replace(btrim(coalesce(item->>'sourceSheet', '')), '\s+', ' ', 'g');
      event_category := item->>'category';
      event_starts_on := (item->>'startsOn')::date;
      event_ends_on := (item->>'endsOn')::date;
      event_is_all_day := (item->>'isAllDay')::boolean;
      event_start_time := case when event_is_all_day then null else (item->>'startTime')::time end;
      event_end_time := case when event_is_all_day then null else (item->>'endTime')::time end;
      event_source_row := (item->>'sourceRow')::integer;
    exception when others then
      raise exception 'invalid_import_event';
    end;

    if char_length(normalized_title) < 1 or char_length(normalized_title) > 80
      or char_length(normalized_description) > 2000
      or char_length(normalized_location) > 100
      or char_length(normalized_office) > 80
      or char_length(normalized_audience) > 120
      or char_length(normalized_sheet) < 1 or char_length(normalized_sheet) > 80
      or event_source_row < 1
      or event_category not in ('class_activity', 'school_activity', 'exam', 'holiday', 'other')
      or event_ends_on < event_starts_on
      or (
        not event_is_all_day and (
          event_start_time is null or event_end_time is null
          or (event_ends_on = event_starts_on and event_end_time <= event_start_time)
        )
      ) then
      raise exception 'invalid_import_event';
    end if;

    event_source_key := md5(concat_ws(
      '|',
      lower(normalized_title),
      event_starts_on::text,
      event_ends_on::text,
      lower(normalized_office),
      lower(normalized_audience)
    ));

    insert into public.calendar_events (
      class_id, title, description, location, category, starts_on, ends_on,
      is_all_day, start_time, end_time, source_office, source_audience,
      source_file_name, source_sheet, source_row, source_key,
      created_by, last_updated_by
    ) values (
      p_class_id,
      normalized_title,
      nullif(normalized_description, ''),
      nullif(normalized_location, ''),
      event_category,
      event_starts_on,
      event_ends_on,
      event_is_all_day,
      event_start_time,
      event_end_time,
      nullif(normalized_office, ''),
      nullif(normalized_audience, ''),
      normalized_source_file,
      normalized_sheet,
      event_source_row,
      event_source_key,
      auth.uid(),
      auth.uid()
    )
    on conflict (class_id, source_key) where source_key is not null do nothing;

    get diagnostics affected_rows = row_count;
    if affected_rows = 1 then
      imported_count := imported_count + 1;
      first_date := least(coalesce(first_date, event_starts_on), event_starts_on);
    else
      skipped_count := skipped_count + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'importedCount', imported_count,
    'skippedCount', skipped_count,
    'firstDate', first_date
  );
end;
$$;

revoke all on function public.admin_import_calendar_events(uuid, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.admin_import_calendar_events(uuid, text, jsonb)
  to authenticated;

commit;
