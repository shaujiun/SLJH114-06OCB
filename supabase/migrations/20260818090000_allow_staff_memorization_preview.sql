-- Approved administrators and teachers may preview the active memorization
-- batch. Preview completions never write student progress.
begin;

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
  current_user_type text;
  preview_mode boolean := false;
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

  if current_student_id is null then
    select profile.user_type
    into current_user_type
    from public.contact_book_profiles profile
    where profile.id = auth.uid()
      and profile.is_active
      and profile.approval_status = 'approved'
      and profile.user_type in ('admin', 'teacher')
    limit 1;

    if current_user_type is null then return null; end if;

    preview_mode := true;
    select memorization_set.class_id
    into current_class_id
    from public.schulte_memorization_sets memorization_set
    join public.classes class on class.id = memorization_set.class_id
    where memorization_set.is_active
      and class.is_active
      and memorization_set.created_at::date <= p_reference_date
      and memorization_set.test_date >= p_reference_date
    order by memorization_set.test_date, class.grade_level, class.class_number
    limit 1;

    if current_class_id is null then return null; end if;
  end if;

  with ordered_sets as (
    select
      memorization_set.*,
      lag(memorization_set.test_date) over (
        partition by memorization_set.class_id order by memorization_set.test_date
      ) as previous_test_date
    from public.schulte_memorization_sets memorization_set
    where memorization_set.class_id = current_class_id
      and memorization_set.is_active
  ), available_sets as (
    select
      ordered_sets.*,
      greatest(
        ordered_sets.created_at::date,
        coalesce(ordered_sets.previous_test_date + 1, ordered_sets.created_at::date)
      ) as available_from
    from ordered_sets
  )
  select
    available_sets.*,
    (progress.passed_at is not null) as passed,
    coalesce(progress.attempt_count, 0) as attempt_count
  into selected_set
  from available_sets
  left join public.schulte_memorization_progress progress
    on progress.set_id = available_sets.id
   and progress.student_id = current_student_id
  where available_sets.available_from <= p_reference_date
    and p_reference_date <= available_sets.test_date
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
    'passed', selected_set.passed,
    'attemptCount', selected_set.attempt_count,
    'preview', preview_mode,
    'viewerRole', coalesce(current_user_type, 'student'),
    'items', selected_items
  );
end;
$$;

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
  current_user_type text;
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
    select profile.user_type
    into current_user_type
    from public.contact_book_profiles profile
    where profile.id = auth.uid()
      and profile.is_active
      and profile.approval_status = 'approved'
      and profile.user_type in ('admin', 'teacher')
    limit 1;

    if current_user_type is null then
      raise exception using errcode = 'P0001', message = 'student_profile_not_found';
    end if;

    select * into selected_set
    from public.schulte_memorization_sets memorization_set
    where memorization_set.id = p_set_id
      and memorization_set.is_active;
    if selected_set.id is null then
      raise exception using errcode = 'P0001', message = 'memorization_set_not_found';
    end if;

    return jsonb_build_object(
      'passed', true,
      'setId', p_set_id,
      'preview', true,
      'viewerRole', current_user_type
    );
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

  return jsonb_build_object(
    'passed', true,
    'setId', p_set_id,
    'preview', false,
    'viewerRole', 'student'
  );
end;
$$;

revoke all on function public.get_my_schulte_memorization_batch(date) from public;
revoke all on function public.get_my_schulte_memorization_batch(date) from anon;
grant execute on function public.get_my_schulte_memorization_batch(date) to authenticated;

revoke all on function public.record_schulte_memorization_completion(uuid, integer, integer) from public;
revoke all on function public.record_schulte_memorization_completion(uuid, integer, integer) from anon;
grant execute on function public.record_schulte_memorization_completion(uuid, integer, integer) to authenticated;

commit;
