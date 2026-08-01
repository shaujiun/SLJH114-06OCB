-- 學習系統入口可設定共同、數學 A/B 組或英語 A/B 組對象。
alter table public.learning_systems
  add column if not exists audience_scope text not null default 'common';

alter table public.learning_systems
  drop constraint if exists learning_systems_audience_scope_check;

alter table public.learning_systems
  add constraint learning_systems_audience_scope_check
  check (audience_scope in ('common', 'math_a', 'math_b', 'english_a', 'english_b'));

create index if not exists learning_systems_active_audience_order_idx
  on public.learning_systems(is_active, audience_scope, display_order);

create or replace function public.resolve_student_learning_group(
  p_student_id uuid,
  p_subject_code text,
  p_reference_date date default current_date
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  normalized_subject text := lower(trim(coalesce(p_subject_code, '')));
  resolved_group text;
begin
  if normalized_subject not in ('math', 'english') then
    return 'COMMON';
  end if;

  select upper(grouping.group_code::text)
  into resolved_group
  from public.student_subject_groups grouping
  join public.class_subjects class_subject on class_subject.id = grouping.class_subject_id
  join public.subjects subject on subject.id = class_subject.subject_id
  where grouping.student_id = p_student_id
    and lower(subject.code::text) = normalized_subject
  order by
    case
      when grouping.effective_from <= p_reference_date
        and (grouping.effective_to is null or grouping.effective_to >= p_reference_date) then 0
      when grouping.effective_from > p_reference_date then 1
      else 2
    end,
    case when grouping.effective_from > p_reference_date then grouping.effective_from end asc,
    grouping.effective_from desc
  limit 1;

  return coalesce(resolved_group, 'B');
end;
$$;

create or replace function public.learning_system_matches_student(
  p_audience_scope text,
  p_student_id uuid,
  p_reference_date date default current_date
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  normalized_scope text := lower(coalesce(p_audience_scope, 'common'));
  target_subject text;
  target_group text;
  resolved_group text;
begin
  if normalized_scope = 'common' then
    return true;
  end if;

  case normalized_scope
    when 'math_a' then target_subject := 'math'; target_group := 'A';
    when 'math_b' then target_subject := 'math'; target_group := 'B';
    when 'english_a' then target_subject := 'english'; target_group := 'A';
    when 'english_b' then target_subject := 'english'; target_group := 'B';
    else return false;
  end case;

  resolved_group := public.resolve_student_learning_group(
    p_student_id,
    target_subject,
    p_reference_date
  );
  return upper(coalesce(resolved_group, 'B')) = target_group;
end;
$$;

revoke all on function public.learning_system_matches_student(text, uuid, date) from public;
revoke all on function public.learning_system_matches_student(text, uuid, date) from anon;
revoke all on function public.learning_system_matches_student(text, uuid, date) from authenticated;

create or replace function public.ensure_student_focus_week(
  p_reference_date date default current_date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_student_id uuid;
  selected_week_start date := date_trunc('week', p_reference_date::timestamp)::date;
  system_row record;
  activity_row record;
  weekly_target integer;
  task_index integer;
  activity_count integer;
  day_offset integer;
  daily_count integer;
  attempts integer;
  selected_group text;
begin
  select student.id
  into current_student_id
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

  perform pg_advisory_xact_lock(hashtext(current_student_id::text || selected_week_start::text));

  update public.student_focus_tasks
  set status = 'expired', updated_at = now()
  where student_id = current_student_id
    and week_start < selected_week_start
    and status = 'pending';

  if exists (
    select 1 from public.student_focus_week_states state
    where state.student_id = current_student_id
      and state.week_start = selected_week_start
  ) then
    return;
  end if;

  insert into public.student_focus_week_states(student_id, week_start)
  values (current_student_id, selected_week_start);

  for system_row in
    select system.*
    from public.learning_systems system
    where system.is_active
      and public.learning_system_matches_student(
        system.audience_scope,
        current_student_id,
        p_reference_date
      )
      and exists (
        select 1 from public.learning_activities activity
        where activity.learning_system_id = system.id
          and activity.is_active
      )
    order by system.display_order, system.subject_name
  loop
    weekly_target := system_row.weekly_minimum
      + floor(random() * (system_row.weekly_maximum - system_row.weekly_minimum + 1))::integer;

    selected_group := case system_row.audience_scope
      when 'math_a' then 'A'
      when 'math_b' then 'B'
      when 'english_a' then 'A'
      when 'english_b' then 'B'
      else public.resolve_student_learning_group(
        current_student_id,
        system_row.subject_code::text,
        p_reference_date
      )
    end;

    select count(*) into activity_count
    from public.learning_activities activity
    where activity.learning_system_id = system_row.id
      and activity.is_active;

    for task_index in 1..weekly_target loop
      select activity.*
      into activity_row
      from public.learning_activities activity
      where activity.learning_system_id = system_row.id
        and activity.is_active
      order by
        mod(activity.display_order + task_index - 2 + floor(random() * activity_count)::integer, activity_count),
        activity.display_order
      limit 1;

      attempts := 0;
      loop
        day_offset := floor(random() * 5)::integer;
        select count(*) into daily_count
        from public.student_focus_tasks task
        where task.student_id = current_student_id
          and task.week_start = selected_week_start
          and task.assigned_date = selected_week_start + day_offset;
        exit when daily_count < 4;
        attempts := attempts + 1;
        exit when attempts >= 20;
      end loop;

      if daily_count >= 4 then
        select day_number
        into day_offset
        from generate_series(0, 4) as day_number
        order by (
          select count(*)
          from public.student_focus_tasks task
          where task.student_id = current_student_id
            and task.week_start = selected_week_start
            and task.assigned_date = selected_week_start + day_number
        ), random()
        limit 1;
      end if;

      insert into public.student_focus_tasks (
        student_id,
        week_start,
        assigned_date,
        learning_activity_id,
        subject_code_snapshot,
        subject_name_snapshot,
        activity_code_snapshot,
        activity_name_snapshot,
        launch_url_snapshot,
        group_code_snapshot,
        question_count,
        target_score,
        slot_number
      ) values (
        current_student_id,
        selected_week_start,
        selected_week_start + day_offset,
        activity_row.id,
        system_row.subject_code,
        system_row.subject_name,
        activity_row.activity_code,
        activity_row.activity_name,
        system_row.launch_url || activity_row.launch_path,
        selected_group,
        case when selected_group = 'A' then activity_row.question_count_a else activity_row.question_count_b end,
        activity_row.target_score,
        task_index
      );
    end loop;
  end loop;
end;
$$;

revoke all on function public.ensure_student_focus_week(date) from public;
grant execute on function public.ensure_student_focus_week(date) to authenticated;
