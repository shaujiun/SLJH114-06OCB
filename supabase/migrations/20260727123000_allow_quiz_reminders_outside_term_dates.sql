-- Resolve A/B recipients even when a reminder date is outside term dates.
-- A truly empty group no longer blocks the rest of the reminder settings.

create or replace function public.save_daily_quiz_reminders(
  p_class_id uuid,
  p_academic_term_id uuid,
  p_reminder_date date,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_name text;
  item jsonb;
  requested_subject_code text;
  requested_subject_id uuid;
  requested_target_type text;
  requested_group_code text;
  requested_quiz_count integer;
  saved_reminder_id uuid;
  inserted_recipient_count integer;
  saved_count integer := 0;
  total_recipient_count integer := 0;
  empty_audience_count integer := 0;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;

  if p_reminder_date is null
    or jsonb_typeof(coalesce(p_items, 'null'::jsonb)) <> 'array'
    or jsonb_array_length(p_items) > 30 then
    raise exception 'invalid_quiz_reminder_data';
  end if;

  if not exists (
    select 1
    from public.classes class_row
    join public.academic_years year_row
      on year_row.id = class_row.academic_year_id
    join public.academic_terms term_row
      on term_row.academic_year_id = year_row.id
    where class_row.id = p_class_id
      and class_row.is_active
      and term_row.id = p_academic_term_id
  ) then raise exception 'invalid_quiz_reminder_term'; end if;

  if not public.can_manage_daily_quiz_reminders(
    p_class_id,
    p_academic_term_id
  ) then
    raise exception 'quiz_reminder_permission_required' using errcode = '42501';
  end if;

  select profile.display_name into actor_name
  from public.contact_book_profiles profile
  where profile.id = auth.uid()
    and profile.approval_status = 'approved'
    and profile.is_active;
  if actor_name is null then raise exception 'quiz_reminder_permission_required'; end if;

  if exists (
    select 1
    from (
      select
        row_data.class_subject_id,
        row_data.target_type,
        upper(coalesce(row_data.target_group_code, '')) as target_group_code,
        count(*) as item_count
      from jsonb_to_recordset(p_items) as row_data(
        class_subject_id uuid,
        target_type text,
        target_group_code text,
        quiz_count integer
      )
      group by
        row_data.class_subject_id,
        row_data.target_type,
        upper(coalesce(row_data.target_group_code, ''))
      having count(*) > 1
    ) duplicate_item
  ) then raise exception 'duplicate_quiz_reminder_item'; end if;

  update public.daily_quiz_reminders reminder
  set is_active = false,
      updated_by = auth.uid(),
      updated_at = now()
  where reminder.class_id = p_class_id
    and reminder.academic_term_id = p_academic_term_id
    and reminder.reminder_date = p_reminder_date
    and reminder.is_active;

  for item in select value from jsonb_array_elements(p_items)
  loop
    requested_subject_id := (item->>'class_subject_id')::uuid;
    requested_target_type := trim(item->>'target_type');
    requested_group_code := nullif(
      upper(trim(item->>'target_group_code')),
      ''
    );
    requested_quiz_count := (item->>'quiz_count')::integer;

    select subject.code
      into requested_subject_code
    from public.class_subjects class_subject
    join public.subjects subject on subject.id = class_subject.subject_id
    where class_subject.id = requested_subject_id
      and class_subject.class_id = p_class_id
      and class_subject.is_active;
    if not found then raise exception 'invalid_quiz_reminder_subject'; end if;

    if requested_quiz_count not between 1 and 9
      or requested_target_type not in ('common', 'group')
      or (
        requested_target_type = 'common'
        and requested_group_code is not null
      )
      or (
        requested_target_type = 'group'
        and (
          requested_subject_code not in ('math', 'english')
          or requested_group_code not in ('A', 'B')
        )
      ) then raise exception 'invalid_quiz_reminder_data'; end if;

    select reminder.id into saved_reminder_id
    from public.daily_quiz_reminders reminder
    where reminder.class_id = p_class_id
      and reminder.academic_term_id = p_academic_term_id
      and reminder.class_subject_id = requested_subject_id
      and reminder.reminder_date = p_reminder_date
      and reminder.target_type = requested_target_type
      and coalesce(upper(reminder.target_group_code::text), '')
        = coalesce(requested_group_code, '')
    for update;

    if saved_reminder_id is null then
      insert into public.daily_quiz_reminders (
        class_id,
        academic_term_id,
        class_subject_id,
        reminder_date,
        target_type,
        target_group_code,
        quiz_count,
        created_by,
        updated_by,
        created_by_display_name
      ) values (
        p_class_id,
        p_academic_term_id,
        requested_subject_id,
        p_reminder_date,
        requested_target_type,
        requested_group_code,
        requested_quiz_count,
        auth.uid(),
        auth.uid(),
        actor_name
      )
      returning id into saved_reminder_id;
    else
      update public.daily_quiz_reminders reminder
      set quiz_count = requested_quiz_count,
          is_active = true,
          updated_by = auth.uid(),
          updated_at = now()
      where reminder.id = saved_reminder_id;
    end if;

    delete from public.daily_quiz_reminder_recipients recipient
    where recipient.reminder_id = saved_reminder_id;

    if requested_target_type = 'common' then
      insert into public.daily_quiz_reminder_recipients (
        reminder_id,
        student_id,
        audience_source
      )
      select saved_reminder_id, student.id, 'common'
      from public.students student
      where student.class_id = p_class_id
        and student.is_active;
    else
      insert into public.daily_quiz_reminder_recipients (
        reminder_id,
        student_id,
        audience_source,
        group_code_snapshot
      )
      select
        saved_reminder_id,
        student.id,
        'group_snapshot',
        group_snapshot.group_code
      from public.students student
      join lateral (
        select student_group.group_code
        from public.student_subject_groups student_group
        where student_group.student_id = student.id
          and student_group.class_subject_id = requested_subject_id
          and student_group.academic_term_id = p_academic_term_id
        order by
          case
            when student_group.effective_from <= p_reminder_date
              and (
                student_group.effective_to is null
                or student_group.effective_to >= p_reminder_date
              ) then 0
            when student_group.effective_from <= p_reminder_date then 1
            else 2
          end,
          case
            when student_group.effective_from <= p_reminder_date
              then student_group.effective_from
          end desc nulls last,
          case
            when student_group.effective_from > p_reminder_date
              then student_group.effective_from
          end asc nulls last
        limit 1
      ) group_snapshot on group_snapshot.group_code = requested_group_code
      where student.class_id = p_class_id
        and student.is_active;
    end if;

    get diagnostics inserted_recipient_count = row_count;
    if inserted_recipient_count = 0 then
      empty_audience_count := empty_audience_count + 1;
    end if;

    saved_count := saved_count + 1;
    total_recipient_count := total_recipient_count + inserted_recipient_count;
    saved_reminder_id := null;
  end loop;

  return jsonb_build_object(
    'savedCount', saved_count,
    'recipientCount', total_recipient_count,
    'emptyAudienceCount', empty_audience_count,
    'reminderDate', p_reminder_date
  );
exception
  when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'invalid_quiz_reminder_data';
end;
$$;
