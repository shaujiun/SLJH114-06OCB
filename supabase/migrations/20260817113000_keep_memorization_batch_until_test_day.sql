-- Keep the current Friday memorization batch available through its test date,
-- even after the student has passed it. The next batch begins the following day.
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
    'items', selected_items
  );
end;
$$;

revoke all on function public.get_my_schulte_memorization_batch(date) from public;
revoke all on function public.get_my_schulte_memorization_batch(date) from anon;
grant execute on function public.get_my_schulte_memorization_batch(date) to authenticated;
