-- 週五名言佳句背誦：每個班級依測驗日期安排五句，學生需連續全對才通過。

create table if not exists public.schulte_memorization_sets (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  test_date date not null,
  is_active boolean not null default true,
  created_by uuid references public.contact_book_profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_id, test_date)
);

create table if not exists public.schulte_memorization_set_items (
  set_id uuid not null references public.schulte_memorization_sets(id) on delete cascade,
  phrase_id uuid not null references public.schulte_phrase_items(id) on delete cascade,
  display_order smallint not null check (display_order between 1 and 5),
  primary key (set_id, phrase_id),
  unique (set_id, display_order)
);

create table if not exists public.schulte_memorization_progress (
  student_id uuid not null references public.students(id) on delete cascade,
  set_id uuid not null references public.schulte_memorization_sets(id) on delete cascade,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  total_error_count integer not null default 0 check (total_error_count >= 0),
  last_duration_ms integer,
  passed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (student_id, set_id)
);

create index if not exists schulte_memorization_sets_class_date_idx
  on public.schulte_memorization_sets(class_id, test_date);

alter table public.schulte_memorization_sets enable row level security;
alter table public.schulte_memorization_set_items enable row level security;
alter table public.schulte_memorization_progress enable row level security;

drop policy if exists schulte_memorization_sets_admin_all on public.schulte_memorization_sets;
create policy schulte_memorization_sets_admin_all on public.schulte_memorization_sets
for all to authenticated
using (public.contact_book_is_admin())
with check (public.contact_book_is_admin());

drop policy if exists schulte_memorization_items_admin_all on public.schulte_memorization_set_items;
create policy schulte_memorization_items_admin_all on public.schulte_memorization_set_items
for all to authenticated
using (public.contact_book_is_admin())
with check (public.contact_book_is_admin());

drop policy if exists schulte_memorization_progress_admin_read on public.schulte_memorization_progress;
create policy schulte_memorization_progress_admin_read on public.schulte_memorization_progress
for select to authenticated
using (public.contact_book_is_admin());

drop policy if exists schulte_memorization_progress_self_read on public.schulte_memorization_progress;
create policy schulte_memorization_progress_self_read on public.schulte_memorization_progress
for select to authenticated
using (exists (
  select 1
  from public.students student
  where student.id = schulte_memorization_progress.student_id
    and student.profile_id = auth.uid()
));

create or replace function public.can_manage_schulte_memorization()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.contact_book_is_admin();
$$;

revoke all on function public.can_manage_schulte_memorization() from public;
revoke all on function public.can_manage_schulte_memorization() from anon;
grant execute on function public.can_manage_schulte_memorization() to authenticated;

create or replace function public.upsert_schulte_memorization_set(
  p_class_id uuid,
  p_test_date date,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_set_id uuid;
  item jsonb;
  selected_phrase_id uuid;
  item_index integer := 0;
  normalized_content text;
  normalized_meaning text;
  normalized_source text;
begin
  if not public.contact_book_is_admin() then
    raise exception using errcode = '42501', message = 'admin_required';
  end if;
  if p_class_id is null or not exists (select 1 from public.classes where id = p_class_id) then
    raise exception using errcode = '22023', message = 'class_not_found';
  end if;
  if p_test_date is null then
    raise exception using errcode = '22023', message = 'test_date_required';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) <> 5 then
    raise exception using errcode = '22023', message = 'exactly_five_phrases_required';
  end if;

  insert into public.schulte_memorization_sets(class_id, test_date, is_active, updated_at)
  values (p_class_id, p_test_date, true, now())
  on conflict (class_id, test_date) do update set
    is_active = true,
    updated_at = now()
  returning id into selected_set_id;

  delete from public.schulte_memorization_set_items where set_id = selected_set_id;

  for item in select value from jsonb_array_elements(p_items)
  loop
    item_index := item_index + 1;
    normalized_content := trim(coalesce(item->>'content', ''));
    normalized_meaning := trim(coalesce(item->>'meaning', ''));
    normalized_source := trim(coalesce(item->>'source', ''));
    if char_length(regexp_replace(normalized_content, '[，。！？；、,.!?;[:space:]]', '', 'g')) < 2
      or char_length(regexp_replace(normalized_content, '[，。！？；、,.!?;[:space:]]', '', 'g')) > 20 then
      raise exception using errcode = '22023', message = 'invalid_phrase_content';
    end if;
    if char_length(normalized_meaning) < 2 or char_length(normalized_meaning) > 240 then
      raise exception using errcode = '22023', message = 'invalid_phrase_meaning';
    end if;

    insert into public.schulte_phrase_items(
      category, title, content, meaning, source, is_active, updated_at
    ) values (
      'quote', left(normalized_content, 20), normalized_content,
      normalized_meaning, left(normalized_source, 80), true, now()
    )
    on conflict (content) do update set
      category = 'quote',
      meaning = excluded.meaning,
      source = excluded.source,
      is_active = true,
      updated_at = now()
    returning id into selected_phrase_id;

    insert into public.schulte_memorization_set_items(set_id, phrase_id, display_order)
    values (selected_set_id, selected_phrase_id, item_index);
  end loop;

  return selected_set_id;
end;
$$;

revoke all on function public.upsert_schulte_memorization_set(uuid, date, jsonb) from public;
revoke all on function public.upsert_schulte_memorization_set(uuid, date, jsonb) from anon;
grant execute on function public.upsert_schulte_memorization_set(uuid, date, jsonb) to authenticated;

create or replace function public.get_my_schulte_memorization_batch(
  p_reference_date date default current_date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_student_id uuid;
  current_class_id uuid;
  selected_set record;
  selected_items jsonb;
begin
  p_reference_date := least(coalesce(p_reference_date, current_date), current_date);

  select student.id, student.class_id
  into current_student_id, current_class_id
  from public.students student
  join public.contact_book_profiles profile on profile.id = student.profile_id
  where student.profile_id = auth.uid()
    and student.is_active
    and profile.is_active
    and profile.approval_status = 'approved'
  limit 1;

  if current_student_id is null then return null; end if;

  with ordered_sets as (
    select
      memorization_set.*,
      lag(memorization_set.test_date) over (
        partition by memorization_set.class_id order by memorization_set.test_date
      ) as previous_test_date
    from public.schulte_memorization_sets memorization_set
    where memorization_set.class_id = current_class_id
      and memorization_set.is_active
  ), scheduled_sets as (
    select
      ordered_sets.*,
      greatest(
        ordered_sets.created_at::date,
        coalesce(ordered_sets.previous_test_date + 1, ordered_sets.created_at::date)
      ) as period_start
    from ordered_sets
  ), available_sets as (
    select
      scheduled_sets.*,
      scheduled_sets.period_start as available_from
    from scheduled_sets
  )
  select available_sets.*
  into selected_set
  from available_sets
  left join public.schulte_memorization_progress progress
    on progress.set_id = available_sets.id
   and progress.student_id = current_student_id
  where available_sets.available_from <= p_reference_date
    and progress.passed_at is null
  order by available_sets.test_date, available_sets.created_at
  limit 1;

  if selected_set.id is null then return null; end if;

  select jsonb_agg(jsonb_build_object(
    'id', phrase.id,
    'content', phrase.content,
    'meaning', phrase.meaning,
    'source', phrase.source,
    'displayOrder', set_item.display_order
  ) order by set_item.display_order)
  into selected_items
  from public.schulte_memorization_set_items set_item
  join public.schulte_phrase_items phrase on phrase.id = set_item.phrase_id
  where set_item.set_id = selected_set.id;

  if jsonb_array_length(coalesce(selected_items, '[]'::jsonb)) <> 5 then return null; end if;

  return jsonb_build_object(
    'setId', selected_set.id,
    'classId', selected_set.class_id,
    'testDate', selected_set.test_date,
    'availableFrom', selected_set.available_from,
    'items', selected_items
  );
end;
$$;

revoke all on function public.get_my_schulte_memorization_batch(date) from public;
revoke all on function public.get_my_schulte_memorization_batch(date) from anon;
grant execute on function public.get_my_schulte_memorization_batch(date) to authenticated;

create or replace function public.record_schulte_memorization_completion(
  p_set_id uuid,
  p_duration_ms integer,
  p_error_count integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_student_id uuid;
  current_class_id uuid;
  selected_set public.schulte_memorization_sets%rowtype;
begin
  if p_duration_ms < 1 or p_duration_ms > 7200000 then
    raise exception using errcode = '22023', message = 'invalid_schulte_duration';
  end if;
  if p_error_count < 0 or p_error_count > 9999 then
    raise exception using errcode = '22023', message = 'invalid_schulte_error_count';
  end if;

  select student.id, student.class_id
  into current_student_id, current_class_id
  from public.students student
  join public.contact_book_profiles profile on profile.id = student.profile_id
  where student.profile_id = auth.uid()
    and student.is_active
    and profile.is_active
    and profile.approval_status = 'approved'
  limit 1;

  if current_student_id is null then
    raise exception using errcode = 'P0001', message = 'student_profile_not_found';
  end if;

  select * into selected_set
  from public.schulte_memorization_sets
  where id = p_set_id and class_id = current_class_id and is_active;
  if selected_set.id is null then
    raise exception using errcode = 'P0001', message = 'memorization_set_not_found';
  end if;

  insert into public.schulte_memorization_progress(
    student_id, set_id, attempt_count, total_error_count,
    last_duration_ms, passed_at, updated_at
  ) values (
    current_student_id, p_set_id, 1, p_error_count,
    p_duration_ms, now(), now()
  )
  on conflict (student_id, set_id) do update set
    attempt_count = schulte_memorization_progress.attempt_count + 1,
    total_error_count = schulte_memorization_progress.total_error_count + excluded.total_error_count,
    last_duration_ms = excluded.last_duration_ms,
    passed_at = coalesce(schulte_memorization_progress.passed_at, excluded.passed_at),
    updated_at = now();

  return jsonb_build_object('passed', true, 'setId', p_set_id);
end;
$$;

revoke all on function public.record_schulte_memorization_completion(uuid, integer, integer) from public;
revoke all on function public.record_schulte_memorization_completion(uuid, integer, integer) from anon;
grant execute on function public.record_schulte_memorization_completion(uuid, integer, integer) to authenticated;
