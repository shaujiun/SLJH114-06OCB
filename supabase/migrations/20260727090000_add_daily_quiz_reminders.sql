-- Daily quiz-count reminders for the paper contact book.
-- No student scores are stored in this module.

begin;

create table if not exists public.daily_quiz_reminders (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  academic_term_id uuid not null references public.academic_terms(id) on delete restrict,
  class_subject_id uuid not null references public.class_subjects(id) on delete cascade,
  reminder_date date not null,
  target_type text not null check (target_type in ('common', 'group')),
  target_group_code citext,
  quiz_count smallint not null check (quiz_count between 1 and 9),
  created_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  updated_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_by_display_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint daily_quiz_reminder_target_valid check (
    (target_type = 'common' and target_group_code is null)
    or (
      target_type = 'group'
      and upper(trim(target_group_code::text)) in ('A', 'B')
    )
  )
);

create unique index if not exists daily_quiz_reminder_identity_unique
  on public.daily_quiz_reminders (
    class_id,
    academic_term_id,
    class_subject_id,
    reminder_date,
    target_type,
    coalesce(upper(target_group_code::text), '')
  );

create index if not exists daily_quiz_reminders_class_date_idx
  on public.daily_quiz_reminders(class_id, reminder_date desc)
  where is_active;

create table if not exists public.daily_quiz_reminder_recipients (
  reminder_id uuid not null references public.daily_quiz_reminders(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  audience_source text not null check (audience_source in ('common', 'group_snapshot')),
  group_code_snapshot citext,
  created_at timestamptz not null default now(),
  primary key (reminder_id, student_id)
);

create index if not exists daily_quiz_recipients_student_idx
  on public.daily_quiz_reminder_recipients(student_id, reminder_id);

drop trigger if exists daily_quiz_reminders_set_updated_at on public.daily_quiz_reminders;
create trigger daily_quiz_reminders_set_updated_at
before update on public.daily_quiz_reminders
for each row execute function public.contact_book_set_updated_at();

create or replace function public.can_manage_daily_quiz_reminders(
  target_class_id uuid,
  target_academic_term_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_manage_class(target_class_id)
    or exists (
      select 1
      from public.student_helper_assignments helper
      join public.students student on student.id = helper.student_id
      join public.contact_book_profiles profile on profile.id = student.profile_id
      join public.academic_terms term on term.id = helper.academic_term_id
      where student.class_id = target_class_id
        and student.profile_id = auth.uid()
        and student.is_active
        and helper.academic_term_id = target_academic_term_id
        and helper.helper_role = 'homework_leader'
        and helper.class_subject_id is null
        and (
          current_date between term.starts_on and term.ends_on
          or term.id = (
            select upcoming.id
            from public.academic_terms upcoming
            where upcoming.academic_year_id = term.academic_year_id
              and upcoming.starts_on > current_date
            order by upcoming.starts_on
            limit 1
          )
        )
        and helper.starts_on <= greatest(current_date, term.starts_on)
        and (
          helper.ends_on is null
          or helper.ends_on >= greatest(current_date, term.starts_on)
        )
        and profile.approval_status = 'approved'
        and profile.is_active
    );
$$;

create or replace function public.is_current_student_quiz_reminder_recipient(
  target_reminder_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.daily_quiz_reminder_recipients recipient
    where recipient.reminder_id = target_reminder_id
      and recipient.student_id = public.current_student_id()
  );
$$;

alter table public.daily_quiz_reminders enable row level security;
alter table public.daily_quiz_reminder_recipients enable row level security;

drop policy if exists daily_quiz_reminders_read_allowed on public.daily_quiz_reminders;
create policy daily_quiz_reminders_read_allowed on public.daily_quiz_reminders
for select to authenticated using (
  public.can_manage_daily_quiz_reminders(class_id, academic_term_id)
  or (
    is_active
    and public.is_current_student_quiz_reminder_recipient(id)
  )
);

drop policy if exists daily_quiz_recipients_read_allowed on public.daily_quiz_reminder_recipients;
create policy daily_quiz_recipients_read_allowed on public.daily_quiz_reminder_recipients
for select to authenticated using (
  public.is_student_self(student_id)
  or exists (
    select 1
    from public.daily_quiz_reminders reminder
    where reminder.id = reminder_id
      and public.can_manage_daily_quiz_reminders(
        reminder.class_id,
        reminder.academic_term_id
      )
  )
);

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
  target_subject_code text;
  target_subject_id uuid;
  target_type text;
  target_group_code text;
  target_quiz_count integer;
  target_reminder_id uuid;
  recipient_count integer;
  saved_count integer := 0;
  total_recipient_count integer := 0;
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
    target_subject_id := (item->>'class_subject_id')::uuid;
    target_type := trim(item->>'target_type');
    target_group_code := nullif(upper(trim(item->>'target_group_code')), '');
    target_quiz_count := (item->>'quiz_count')::integer;

    select subject.code
      into target_subject_code
    from public.class_subjects class_subject
    join public.subjects subject on subject.id = class_subject.subject_id
    where class_subject.id = target_subject_id
      and class_subject.class_id = p_class_id
      and class_subject.is_active;
    if not found then raise exception 'invalid_quiz_reminder_subject'; end if;

    if target_quiz_count not between 1 and 9
      or target_type not in ('common', 'group')
      or (target_type = 'common' and target_group_code is not null)
      or (
        target_type = 'group'
        and (
          target_subject_code not in ('math', 'english')
          or target_group_code not in ('A', 'B')
        )
      ) then raise exception 'invalid_quiz_reminder_data'; end if;

    select reminder.id into target_reminder_id
    from public.daily_quiz_reminders reminder
    where reminder.class_id = p_class_id
      and reminder.academic_term_id = p_academic_term_id
      and reminder.class_subject_id = target_subject_id
      and reminder.reminder_date = p_reminder_date
      and reminder.target_type = target_type
      and coalesce(upper(reminder.target_group_code::text), '')
        = coalesce(target_group_code, '')
    for update;

    if target_reminder_id is null then
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
        target_subject_id,
        p_reminder_date,
        target_type,
        target_group_code,
        target_quiz_count,
        auth.uid(),
        auth.uid(),
        actor_name
      )
      returning id into target_reminder_id;
    else
      update public.daily_quiz_reminders reminder
      set quiz_count = target_quiz_count,
          is_active = true,
          updated_by = auth.uid(),
          updated_at = now()
      where reminder.id = target_reminder_id;
    end if;

    delete from public.daily_quiz_reminder_recipients recipient
    where recipient.reminder_id = target_reminder_id;

    if target_type = 'common' then
      insert into public.daily_quiz_reminder_recipients (
        reminder_id,
        student_id,
        audience_source
      )
      select target_reminder_id, student.id, 'common'
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
        target_reminder_id,
        student.id,
        'group_snapshot',
        student_group.group_code
      from public.students student
      join public.student_subject_groups student_group
        on student_group.student_id = student.id
      where student.class_id = p_class_id
        and student.is_active
        and student_group.class_subject_id = target_subject_id
        and student_group.academic_term_id = p_academic_term_id
        and student_group.group_code = target_group_code
        and student_group.effective_from <= p_reminder_date
        and (
          student_group.effective_to is null
          or student_group.effective_to >= p_reminder_date
        );
    end if;

    get diagnostics recipient_count = row_count;
    if recipient_count = 0 then raise exception 'empty_quiz_reminder_audience'; end if;

    saved_count := saved_count + 1;
    total_recipient_count := total_recipient_count + recipient_count;
    target_reminder_id := null;
  end loop;

  return jsonb_build_object(
    'savedCount', saved_count,
    'recipientCount', total_recipient_count,
    'reminderDate', p_reminder_date
  );
exception
  when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'invalid_quiz_reminder_data';
end;
$$;

revoke all on function public.can_manage_daily_quiz_reminders(uuid, uuid)
  from public, anon;
grant execute on function public.can_manage_daily_quiz_reminders(uuid, uuid)
  to authenticated;

revoke all on function public.is_current_student_quiz_reminder_recipient(uuid)
  from public, anon;
grant execute on function public.is_current_student_quiz_reminder_recipient(uuid)
  to authenticated;

revoke all on function public.save_daily_quiz_reminders(uuid, uuid, date, jsonb)
  from public, anon, authenticated;
grant execute on function public.save_daily_quiz_reminders(uuid, uuid, date, jsonb)
  to authenticated;

commit;
