-- 線上聯絡簿：Supabase 初步資料模型
-- 狀態：設計草案，尚未在任何 Supabase 專案執行。

create extension if not exists pgcrypto;
create extension if not exists citext;
create extension if not exists btree_gist;

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.academic_years (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  school_year integer not null check (school_year > 0),
  starts_on date not null,
  ends_on date not null,
  created_at timestamptz not null default now(),
  constraint academic_year_dates_valid check (ends_on >= starts_on),
  constraint academic_year_school_unique unique (school_id, school_year)
);

create table if not exists public.academic_terms (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  semester smallint not null check (semester between 1 and 3),
  starts_on date not null,
  ends_on date not null,
  created_at timestamptz not null default now(),
  constraint academic_term_dates_valid check (ends_on >= starts_on),
  constraint academic_term_year_unique unique (academic_year_id, semester)
);

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  academic_year_id uuid not null references public.academic_years(id) on delete cascade,
  grade_level smallint not null check (grade_level between 1 and 12),
  class_number smallint not null check (class_number > 0),
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint class_year_name_unique unique (academic_year_id, name)
);

create table if not exists public.contact_book_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username citext not null unique,
  display_name text not null,
  user_type text not null check (user_type in ('admin', 'teacher', 'student')),
  approval_status text not null default 'pending'
    check (approval_status in ('pending', 'approved', 'rejected', 'suspended')),
  is_active boolean not null default true,
  approved_by uuid references public.contact_book_profiles(id) on delete set null,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  profile_id uuid unique references public.contact_book_profiles(id) on delete set null,
  student_id_code citext not null unique,
  seat_number smallint not null check (seat_number > 0),
  full_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_class_seat_unique unique (class_id, seat_number)
);

create table if not exists public.student_activation_codes (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  code_hash text not null,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

create unique index if not exists one_unused_activation_code_per_student
  on public.student_activation_codes(student_id)
  where used_at is null;

-- 公開登入端點的節流狀態。只保存雜湊後的請求識別，不保存原始 IP 或帳號。
create table if not exists public.auth_rate_limits (
  key_hash text not null,
  action text not null,
  window_started_at timestamptz not null default now(),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  blocked_until timestamptz,
  updated_at timestamptz not null default now(),
  primary key (key_hash, action)
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  code citext not null,
  name text not null,
  created_at timestamptz not null default now(),
  constraint subject_school_code_unique unique (school_id, code),
  constraint subject_school_name_unique unique (school_id, name)
);

create table if not exists public.class_subjects (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  subject_id uuid not null references public.subjects(id) on delete restrict,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint class_subject_unique unique (class_id, subject_id)
);

create table if not exists public.class_staff_assignments (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  profile_id uuid not null references public.contact_book_profiles(id) on delete cascade,
  role text not null check (role in ('homeroom_teacher', 'subject_teacher')),
  class_subject_id uuid references public.class_subjects(id) on delete cascade,
  starts_on date not null,
  ends_on date,
  created_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint staff_assignment_dates_valid check (ends_on is null or ends_on >= starts_on),
  constraint staff_subject_role_valid check (
    (role = 'homeroom_teacher' and class_subject_id is null)
    or (role = 'subject_teacher' and class_subject_id is not null)
  )
);

create unique index if not exists active_staff_assignment_unique
  on public.class_staff_assignments(class_id, profile_id, role, coalesce(class_subject_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where ends_on is null;

create table if not exists public.student_helper_assignments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  academic_term_id uuid not null references public.academic_terms(id) on delete cascade,
  class_subject_id uuid references public.class_subjects(id) on delete cascade,
  helper_role text not null check (helper_role in ('homework_leader', 'subject_helper')),
  starts_on date not null,
  ends_on date,
  created_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint helper_assignment_dates_valid check (ends_on is null or ends_on >= starts_on),
  constraint helper_subject_role_valid check (
    (helper_role = 'homework_leader' and class_subject_id is null)
    or (helper_role = 'subject_helper' and class_subject_id is not null)
  )
);

create unique index if not exists helper_assignment_term_unique
  on public.student_helper_assignments(
    student_id,
    academic_term_id,
    helper_role,
    coalesce(class_subject_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

create table if not exists public.student_subject_groups (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  class_subject_id uuid not null references public.class_subjects(id) on delete cascade,
  academic_term_id uuid not null references public.academic_terms(id) on delete cascade,
  group_code citext not null check (length(trim(group_code::text)) > 0),
  effective_from date not null,
  effective_to date,
  created_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint student_group_dates_valid check (effective_to is null or effective_to >= effective_from),
  constraint student_group_period_no_overlap exclude using gist (
    student_id with =,
    class_subject_id with =,
    daterange(effective_from, coalesce(effective_to, 'infinity'::date), '[]') with &&
  )
);

create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  class_subject_id uuid not null references public.class_subjects(id) on delete cascade,
  academic_term_id uuid not null references public.academic_terms(id) on delete restrict,
  assignment_date date not null,
  content text not null check (length(trim(content)) > 0),
  due_at timestamptz not null,
  target_type text not null check (target_type in ('common', 'group')),
  target_group_code citext,
  published_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  published_by_display_name text not null,
  published_at timestamptz not null default now(),
  is_active boolean not null default true,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint assignment_target_valid check (
    (target_type = 'common' and target_group_code is null)
    or (target_type = 'group' and target_group_code is not null)
  )
);

create index if not exists assignments_subject_due_idx
  on public.assignments(class_subject_id, due_at desc);

create table if not exists public.assignment_recipients (
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  audience_source text not null check (audience_source in ('common', 'group_snapshot', 'manual_adjustment')),
  group_code_snapshot citext,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (assignment_id, student_id)
);

create index if not exists assignment_recipients_student_idx
  on public.assignment_recipients(student_id, assignment_id);

create table if not exists public.submission_checks (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  check_stage text not null check (check_stage in ('helper', 'teacher')),
  result text not null check (result in ('all_submitted', 'exceptions_recorded')),
  checked_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  checked_at timestamptz not null default now(),
  note text,
  constraint submission_check_assignment_stage_unique unique (assignment_id, check_stage)
);

create table if not exists public.submission_exceptions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  initial_reason text not null
    check (initial_reason in ('incomplete', 'not_brought', 'late', 'leave', 'official_leave', 'exempt')),
  current_reason text not null
    check (current_reason in ('incomplete', 'not_brought', 'late', 'leave', 'official_leave', 'exempt')),
  workflow_state text not null default 'open'
    check (workflow_state in ('open', 'made_up', 'waived')),
  follow_up_due_at timestamptz,
  counts_as_missing boolean not null default false,
  counts_as_late boolean not null default false,
  resolved_at timestamptz,
  hide_after timestamptz,
  first_recorded_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  last_updated_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint submission_exception_assignment_student_unique unique (assignment_id, student_id),
  constraint absence_follow_up_required check (
    current_reason not in ('leave', 'official_leave') or follow_up_due_at is not null
  ),
  constraint resolved_dates_valid check (
    (workflow_state = 'open' and resolved_at is null and hide_after is null)
    or (workflow_state in ('made_up', 'waived') and resolved_at is not null and hide_after is not null)
  )
);

create index if not exists submission_exceptions_student_idx
  on public.submission_exceptions(student_id, created_at desc);

create index if not exists submission_exceptions_active_idx
  on public.submission_exceptions(workflow_state, hide_after);

create table if not exists public.submission_status_events (
  id uuid primary key default gen_random_uuid(),
  submission_exception_id uuid not null references public.submission_exceptions(id) on delete cascade,
  from_reason text,
  to_reason text not null,
  from_state text,
  to_state text not null,
  counts_as_missing boolean not null,
  counts_as_late boolean not null,
  changed_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists submission_events_exception_idx
  on public.submission_status_events(submission_exception_id, created_at);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  scope text not null check (scope in ('school', 'class')),
  title text not null check (length(trim(title)) > 0),
  content text,
  image_path text,
  image_alt_text text,
  published_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  published_at timestamptz not null default now(),
  expires_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists announcements_class_published_idx
  on public.announcements(class_id, published_at desc);

create table if not exists public.announcement_reads (
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (announcement_id, student_id)
);

create table if not exists public.honor_entries (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  student_display_name text not null,
  title text not null check (length(trim(title)) > 0),
  description text,
  awarded_on date not null,
  created_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  is_visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists honor_entries_class_date_idx
  on public.honor_entries(class_id, awarded_on desc);

-- 成績模組僅預留資料結構，第一版不建立正式操作畫面。
create table if not exists public.assessment_periods (
  id uuid primary key default gen_random_uuid(),
  academic_term_id uuid not null references public.academic_terms(id) on delete cascade,
  name text not null,
  starts_on date,
  ends_on date,
  sort_order integer not null default 0,
  constraint assessment_period_term_name_unique unique (academic_term_id, name)
);

create table if not exists public.assessments (
  id uuid primary key default gen_random_uuid(),
  class_subject_id uuid not null references public.class_subjects(id) on delete cascade,
  assessment_period_id uuid not null references public.assessment_periods(id) on delete cascade,
  name text not null,
  maximum_score numeric(7, 2) not null default 100 check (maximum_score > 0),
  assessed_on date,
  created_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.student_scores (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  score numeric(7, 2) not null check (score >= 0),
  recorded_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_assessment_score_unique unique (assessment_id, student_id)
);

-- 由 Edge Function 使用 service_role 呼叫，將學生啟用相關資料以單一交易完成。
create or replace function public.complete_student_activation(
  p_student_id_code text,
  p_code_hash text,
  p_profile_id uuid,
  p_username text
)
returns table (student_id uuid, display_name text)
language plpgsql
security definer
set search_path = public
as $$
declare
  target_student public.students%rowtype;
  target_code public.student_activation_codes%rowtype;
begin
  select * into target_student
  from public.students s
  where s.student_id_code = p_student_id_code
    and s.is_active
  for update;

  if not found or target_student.profile_id is not null then
    raise exception 'invalid_activation';
  end if;

  select * into target_code
  from public.student_activation_codes sac
  where sac.student_id = target_student.id
    and sac.used_at is null
    and sac.expires_at > now()
  for update;

  if not found or target_code.code_hash <> p_code_hash then
    raise exception 'invalid_activation';
  end if;

  insert into public.contact_book_profiles (
    id,
    username,
    display_name,
    user_type,
    approval_status,
    approved_at
  ) values (
    p_profile_id,
    p_username,
    target_student.full_name,
    'student',
    'approved',
    now()
  );

  update public.students
  set profile_id = p_profile_id,
      updated_at = now()
  where id = target_student.id;

  update public.student_activation_codes
  set used_at = now()
  where id = target_code.id;

  return query select target_student.id, target_student.full_name;
end;
$$;

-- 教師自行註冊後只建立 pending profile，導師核准後才給班級與科目權限。
create or replace function public.register_pending_teacher(
  p_profile_id uuid,
  p_username text,
  p_display_name text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.contact_book_profiles (
    id,
    username,
    display_name,
    user_type,
    approval_status
  ) values (
    p_profile_id,
    p_username,
    p_display_name,
    'teacher',
    'pending'
  );
end;
$$;

-- 管理員核准待審教師並一次設定任教科目，整個流程在同一個交易內完成。
create or replace function public.approve_pending_teacher(
  p_profile_id uuid,
  p_class_id uuid,
  p_class_subject_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_profile public.contact_book_profiles%rowtype;
  valid_subject_count integer;
  assignment_start_date date;
begin
  if not public.contact_book_is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  if p_class_subject_ids is null or cardinality(p_class_subject_ids) = 0 then
    raise exception 'subject_required';
  end if;

  select p.* into target_profile
  from public.contact_book_profiles p
  where p.id = p_profile_id
  for update;

  if not found
    or target_profile.user_type <> 'teacher'
    or target_profile.approval_status <> 'pending'
    or not target_profile.is_active then
    raise exception 'invalid_pending_teacher';
  end if;

  select count(*) into valid_subject_count
  from (
    select distinct unnest(p_class_subject_ids) as id
  ) requested
  join public.class_subjects cs on cs.id = requested.id
  where cs.class_id = p_class_id and cs.is_active;

  if valid_subject_count <> cardinality(p_class_subject_ids) then
    raise exception 'invalid_class_subjects';
  end if;

  select greatest(current_date, ay.starts_on)
  into assignment_start_date
  from public.classes c
  join public.academic_years ay on ay.id = c.academic_year_id
  where c.id = p_class_id and c.is_active;

  if assignment_start_date is null then
    raise exception 'invalid_class';
  end if;

  update public.contact_book_profiles
  set approval_status = 'approved',
      approved_by = auth.uid(),
      approved_at = now(),
      updated_at = now()
  where id = p_profile_id;

  insert into public.class_staff_assignments (
    class_id,
    profile_id,
    role,
    class_subject_id,
    starts_on,
    created_by
  )
  select
    p_class_id,
    p_profile_id,
    'subject_teacher',
    requested.id,
    assignment_start_date,
    auth.uid()
  from (
    select distinct unnest(p_class_subject_ids) as id
  ) requested
  on conflict do nothing;

  return jsonb_build_object(
    'profileId', target_profile.id,
    'displayName', target_profile.display_name,
    'assignedSubjectCount', valid_subject_count
  );
end;
$$;

-- 管理員建立學生時，同步保存數英分組與一次性啟用碼雜湊。
create or replace function public.admin_create_student(
  p_class_id uuid,
  p_academic_term_id uuid,
  p_student_id_code text,
  p_seat_number smallint,
  p_full_name text,
  p_math_group text,
  p_english_group text,
  p_code_hash text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  created_student public.students%rowtype;
  math_class_subject_id uuid;
  english_class_subject_id uuid;
  group_effective_from date;
begin
  if not public.contact_book_is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  if trim(p_student_id_code) !~ '^[0-9]{4,20}$'
    or p_seat_number < 1
    or p_seat_number > 99
    or char_length(trim(p_full_name)) < 2
    or char_length(trim(p_full_name)) > 50
    or upper(trim(p_math_group)) not in ('A', 'B')
    or upper(trim(p_english_group)) not in ('A', 'B')
    or p_code_hash !~ '^[0-9a-f]{64}$'
    or p_expires_at <= now() then
    raise exception 'invalid_student_data';
  end if;

  select term.starts_on
  into group_effective_from
  from public.classes c
  join public.academic_terms term
    on term.academic_year_id = c.academic_year_id
  where c.id = p_class_id
    and c.is_active
    and term.id = p_academic_term_id;

  if group_effective_from is null then
    raise exception 'invalid_class_term';
  end if;

  select cs.id into math_class_subject_id
  from public.class_subjects cs
  join public.subjects s on s.id = cs.subject_id
  where cs.class_id = p_class_id
    and cs.is_active
    and s.code = 'math';

  select cs.id into english_class_subject_id
  from public.class_subjects cs
  join public.subjects s on s.id = cs.subject_id
  where cs.class_id = p_class_id
    and cs.is_active
    and s.code = 'english';

  if math_class_subject_id is null or english_class_subject_id is null then
    raise exception 'required_subject_missing';
  end if;

  insert into public.students (
    class_id,
    student_id_code,
    seat_number,
    full_name
  ) values (
    p_class_id,
    trim(p_student_id_code),
    p_seat_number,
    trim(p_full_name)
  )
  returning * into created_student;

  insert into public.student_subject_groups (
    student_id,
    class_subject_id,
    academic_term_id,
    group_code,
    effective_from,
    created_by
  ) values
    (
      created_student.id,
      math_class_subject_id,
      p_academic_term_id,
      upper(trim(p_math_group)),
      group_effective_from,
      auth.uid()
    ),
    (
      created_student.id,
      english_class_subject_id,
      p_academic_term_id,
      upper(trim(p_english_group)),
      group_effective_from,
      auth.uid()
    );

  insert into public.student_activation_codes (
    student_id,
    code_hash,
    expires_at,
    created_by
  ) values (
    created_student.id,
    p_code_hash,
    p_expires_at,
    auth.uid()
  );

  return jsonb_build_object(
    'id', created_student.id,
    'studentIdCode', created_student.student_id_code,
    'seatNumber', created_student.seat_number,
    'fullName', created_student.full_name,
    'mathGroup', upper(trim(p_math_group)),
    'englishGroup', upper(trim(p_english_group))
  );
end;
$$;

create or replace function public.admin_update_student_settings(
  p_student_id uuid,
  p_academic_term_id uuid,
  p_math_group text,
  p_english_group text,
  p_is_homework_leader boolean,
  p_helper_subject_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_student public.students%rowtype;
  term_start date;
  term_end date;
  math_class_subject_id uuid;
  english_class_subject_id uuid;
  valid_helper_count integer;
  desired record;
  current_group public.student_subject_groups%rowtype;
begin
  if not public.contact_book_is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  if upper(trim(p_math_group)) not in ('A', 'B')
    or upper(trim(p_english_group)) not in ('A', 'B') then
    raise exception 'invalid_group';
  end if;

  select * into target_student
  from public.students s
  where s.id = p_student_id and s.is_active
  for update;

  if not found then raise exception 'invalid_student'; end if;

  select term.starts_on, term.ends_on
  into term_start, term_end
  from public.academic_terms term
  join public.classes c on c.academic_year_id = term.academic_year_id
  where term.id = p_academic_term_id
    and c.id = target_student.class_id;

  if term_start is null or current_date > term_end then
    raise exception 'invalid_or_ended_term';
  end if;

  select cs.id into math_class_subject_id
  from public.class_subjects cs
  join public.subjects s on s.id = cs.subject_id
  where cs.class_id = target_student.class_id and cs.is_active and s.code = 'math';

  select cs.id into english_class_subject_id
  from public.class_subjects cs
  join public.subjects s on s.id = cs.subject_id
  where cs.class_id = target_student.class_id and cs.is_active and s.code = 'english';

  select count(*) into valid_helper_count
  from (
    select distinct unnest(coalesce(p_helper_subject_ids, '{}'::uuid[])) as id
  ) requested
  join public.class_subjects cs on cs.id = requested.id
  where cs.class_id = target_student.class_id and cs.is_active;

  if valid_helper_count <> coalesce(cardinality(p_helper_subject_ids), 0) then
    raise exception 'invalid_helper_subjects';
  end if;

  for desired in
    select * from (values
      (math_class_subject_id, upper(trim(p_math_group))),
      (english_class_subject_id, upper(trim(p_english_group)))
    ) as groups(class_subject_id, group_code)
  loop
    if current_date < term_start then
      delete from public.student_subject_groups
      where student_id = target_student.id
        and academic_term_id = p_academic_term_id
        and class_subject_id = desired.class_subject_id;

      insert into public.student_subject_groups (
        student_id, class_subject_id, academic_term_id, group_code, effective_from, created_by
      ) values (
        target_student.id,
        desired.class_subject_id,
        p_academic_term_id,
        desired.group_code,
        term_start,
        auth.uid()
      );
    else
      delete from public.student_subject_groups
      where student_id = target_student.id
        and academic_term_id = p_academic_term_id
        and class_subject_id = desired.class_subject_id
        and effective_from > current_date;

      select * into current_group
      from public.student_subject_groups ssg
      where ssg.student_id = target_student.id
        and ssg.academic_term_id = p_academic_term_id
        and ssg.class_subject_id = desired.class_subject_id
        and ssg.effective_from <= current_date
        and (ssg.effective_to is null or ssg.effective_to >= current_date)
      order by ssg.effective_from desc
      limit 1
      for update;

      if found and current_group.group_code::text <> desired.group_code then
        if current_group.effective_from = current_date then
          update public.student_subject_groups
          set group_code = desired.group_code
          where id = current_group.id;
        else
          update public.student_subject_groups
          set effective_to = current_date - 1
          where id = current_group.id;

          insert into public.student_subject_groups (
            student_id, class_subject_id, academic_term_id, group_code, effective_from, created_by
          ) values (
            target_student.id,
            desired.class_subject_id,
            p_academic_term_id,
            desired.group_code,
            current_date,
            auth.uid()
          );
        end if;
      elsif not found then
        insert into public.student_subject_groups (
          student_id, class_subject_id, academic_term_id, group_code, effective_from, created_by
        ) values (
          target_student.id,
          desired.class_subject_id,
          p_academic_term_id,
          desired.group_code,
          current_date,
          auth.uid()
        );
      end if;
    end if;
  end loop;

  delete from public.student_helper_assignments
  where student_id = target_student.id
    and academic_term_id = p_academic_term_id;

  if coalesce(p_is_homework_leader, false) then
    insert into public.student_helper_assignments (
      student_id, academic_term_id, class_subject_id, helper_role,
      starts_on, ends_on, created_by
    ) values (
      target_student.id, p_academic_term_id, null, 'homework_leader',
      term_start, term_end, auth.uid()
    );
  end if;

  insert into public.student_helper_assignments (
    student_id, academic_term_id, class_subject_id, helper_role,
    starts_on, ends_on, created_by
  )
  select
    target_student.id,
    p_academic_term_id,
    requested.id,
    'subject_helper',
    term_start,
    term_end,
    auth.uid()
  from (
    select distinct unnest(coalesce(p_helper_subject_ids, '{}'::uuid[])) as id
  ) requested;

  return jsonb_build_object(
    'studentId', target_student.id,
    'mathGroup', upper(trim(p_math_group)),
    'englishGroup', upper(trim(p_english_group)),
    'isHomeworkLeader', coalesce(p_is_homework_leader, false),
    'helperSubjectCount', valid_helper_count
  );
end;
$$;

create or replace function public.admin_replace_student_activation(
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
begin
  if not public.contact_book_is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  if p_code_hash !~ '^[0-9a-f]{64}$' or p_expires_at <= now() then
    raise exception 'invalid_activation_data';
  end if;

  select * into target_student
  from public.students s
  where s.id = p_student_id and s.is_active
  for update;

  if not found then raise exception 'invalid_student'; end if;
  if target_student.profile_id is not null then raise exception 'already_activated'; end if;

  update public.student_activation_codes
  set used_at = now()
  where student_id = target_student.id and used_at is null;

  insert into public.student_activation_codes (
    student_id, code_hash, expires_at, created_by
  ) values (
    target_student.id, p_code_hash, p_expires_at, auth.uid()
  );

  return jsonb_build_object(
    'studentId', target_student.id,
    'studentIdCode', target_student.student_id_code,
    'fullName', target_student.full_name
  );
end;
$$;

create or replace function public.publish_contact_book_assignment(
  p_class_subject_id uuid,
  p_academic_term_id uuid,
  p_assignment_date date,
  p_content text,
  p_due_at timestamptz,
  p_target_type text,
  p_target_group_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  publisher public.contact_book_profiles%rowtype;
  target_class_id uuid;
  created_assignment public.assignments%rowtype;
  recipient_count integer;
begin
  if not public.can_publish_subject(p_class_subject_id) then
    raise exception 'publish_permission_required' using errcode = '42501';
  end if;

  if char_length(trim(p_content)) < 1
    or char_length(trim(p_content)) > 1000
    or p_due_at < p_assignment_date::timestamptz
    or p_target_type not in ('common', 'group')
    or (p_target_type = 'group' and upper(trim(p_target_group_code)) not in ('A', 'B'))
    or (p_target_type = 'common' and p_target_group_code is not null) then
    raise exception 'invalid_assignment_data';
  end if;

  select p.* into publisher
  from public.contact_book_profiles p
  where p.id = auth.uid() and p.approval_status = 'approved' and p.is_active;
  if not found then raise exception 'invalid_publisher'; end if;

  select cs.class_id into target_class_id
  from public.class_subjects cs
  join public.classes c on c.id = cs.class_id and c.is_active
  join public.academic_terms term
    on term.id = p_academic_term_id
    and term.academic_year_id = c.academic_year_id
  where cs.id = p_class_subject_id
    and cs.is_active
    and p_assignment_date between term.starts_on and term.ends_on;
  if target_class_id is null then raise exception 'invalid_class_subject_term'; end if;

  insert into public.assignments (
    class_subject_id, academic_term_id, assignment_date, content, due_at,
    target_type, target_group_code, published_by, published_by_display_name
  ) values (
    p_class_subject_id,
    p_academic_term_id,
    p_assignment_date,
    trim(p_content),
    p_due_at,
    p_target_type,
    case when p_target_type = 'group' then upper(trim(p_target_group_code)) else null end,
    publisher.id,
    publisher.display_name
  ) returning * into created_assignment;

  if p_target_type = 'common' then
    insert into public.assignment_recipients (assignment_id, student_id, audience_source)
    select created_assignment.id, s.id, 'common'
    from public.students s
    where s.class_id = target_class_id and s.is_active;
  else
    insert into public.assignment_recipients (
      assignment_id, student_id, audience_source, group_code_snapshot
    )
    select created_assignment.id, s.id, 'group_snapshot', ssg.group_code
    from public.students s
    join public.student_subject_groups ssg
      on ssg.student_id = s.id
      and ssg.class_subject_id = p_class_subject_id
      and ssg.academic_term_id = p_academic_term_id
      and ssg.effective_from <= p_assignment_date
      and (ssg.effective_to is null or ssg.effective_to >= p_assignment_date)
    where s.class_id = target_class_id
      and s.is_active
      and ssg.group_code = upper(trim(p_target_group_code));
  end if;

  get diagnostics recipient_count = row_count;
  if recipient_count = 0 then raise exception 'empty_assignment_audience'; end if;

  return jsonb_build_object(
    'id', created_assignment.id,
    'recipientCount', recipient_count,
    'targetType', created_assignment.target_type,
    'targetGroupCode', created_assignment.target_group_code
  );
end;
$$;

create or replace function public.record_assignment_submission_check(
  p_assignment_id uuid,
  p_stage text,
  p_result text,
  p_exceptions jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_assignment public.assignments%rowtype;
  requested_count integer;
  unique_count integer;
  open_count integer;
begin
  select * into target_assignment
  from public.assignments a
  where a.id = p_assignment_id and a.is_active
  for update;
  if not found then raise exception 'invalid_assignment'; end if;

  if p_stage not in ('helper', 'teacher')
    or p_result not in ('all_submitted', 'exceptions_recorded')
    or jsonb_typeof(coalesce(p_exceptions, '[]'::jsonb)) <> 'array' then
    raise exception 'invalid_submission_check';
  end if;

  if not public.can_publish_subject(target_assignment.class_subject_id)
    or (p_stage = 'teacher' and not public.can_manage_subject(target_assignment.class_subject_id)) then
    raise exception 'submission_permission_required' using errcode = '42501';
  end if;

  select count(*), count(distinct x.student_id)
  into requested_count, unique_count
  from jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
    as x(student_id uuid, reason text, follow_up_due_at timestamptz);

  if requested_count <> unique_count
    or (p_result = 'all_submitted' and requested_count <> 0)
    or (p_result = 'exceptions_recorded' and requested_count = 0)
    or exists (
      select 1
      from jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
        as x(student_id uuid, reason text, follow_up_due_at timestamptz)
      where x.reason not in ('incomplete', 'not_brought', 'late', 'leave', 'official_leave', 'exempt')
        or (x.reason in ('leave', 'official_leave') and x.follow_up_due_at is null)
        or not exists (
          select 1 from public.assignment_recipients ar
          where ar.assignment_id = p_assignment_id and ar.student_id = x.student_id
        )
    ) then
    raise exception 'invalid_submission_exceptions';
  end if;

  insert into public.submission_checks (
    assignment_id, check_stage, result, checked_by, checked_at
  ) values (
    p_assignment_id, p_stage, p_result, auth.uid(), now()
  )
  on conflict (assignment_id, check_stage) do update
  set result = excluded.result,
      checked_by = excluded.checked_by,
      checked_at = excluded.checked_at;

  if p_stage = 'teacher' then
    update public.submission_exceptions se
    set workflow_state = 'made_up',
        counts_as_late = se.counts_as_late or not (
          se.current_reason in ('leave', 'official_leave')
          and se.follow_up_due_at is not null
          and now() <= se.follow_up_due_at
        ),
        last_updated_by = auth.uid()
    where se.assignment_id = p_assignment_id
      and se.workflow_state = 'open'
      and (
        p_result = 'all_submitted'
        or not exists (
          select 1
          from jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
            as x(student_id uuid, reason text, follow_up_due_at timestamptz)
          where x.student_id = se.student_id
        )
      );
  end if;

  if p_result = 'exceptions_recorded' then
    insert into public.submission_exceptions (
      assignment_id, student_id, initial_reason, current_reason, workflow_state,
      follow_up_due_at, counts_as_missing, counts_as_late,
      first_recorded_by, last_updated_by
    )
    select
      p_assignment_id,
      x.student_id,
      x.reason,
      x.reason,
      'open',
      x.follow_up_due_at,
      x.reason in ('incomplete', 'not_brought'),
      x.reason = 'late',
      auth.uid(),
      auth.uid()
    from jsonb_to_recordset(p_exceptions)
      as x(student_id uuid, reason text, follow_up_due_at timestamptz)
    on conflict (assignment_id, student_id) do update
    set current_reason = excluded.current_reason,
        workflow_state = 'open',
        follow_up_due_at = excluded.follow_up_due_at,
        counts_as_missing = submission_exceptions.counts_as_missing or excluded.counts_as_missing,
        counts_as_late = submission_exceptions.counts_as_late or excluded.counts_as_late,
        last_updated_by = auth.uid();
  end if;

  update public.assignment_recipients recipient
  set submitted_at = case
    when exists (
      select 1
      from jsonb_to_recordset(coalesce(p_exceptions, '[]'::jsonb))
        as x(student_id uuid, reason text, follow_up_due_at timestamptz)
      where x.student_id = recipient.student_id
    ) then null
    else now()
  end
  where recipient.assignment_id = p_assignment_id;

  select count(*) into open_count
  from public.submission_exceptions se
  where se.assignment_id = p_assignment_id and se.workflow_state = 'open';

  return jsonb_build_object(
    'assignmentId', p_assignment_id,
    'stage', p_stage,
    'result', p_result,
    'exceptionCount', requested_count,
    'openExceptionCount', open_count
  );
end;
$$;

create or replace function public.consume_auth_rate_limit(
  p_key_hash text,
  p_action text,
  p_limit integer,
  p_window_seconds integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  current_record public.auth_rate_limits%rowtype;
  window_interval interval;
begin
  if p_limit < 1 or p_window_seconds < 1 then
    raise exception 'invalid_rate_limit_config';
  end if;

  window_interval := make_interval(secs => p_window_seconds);

  insert into public.auth_rate_limits (key_hash, action, attempt_count)
  values (p_key_hash, p_action, 0)
  on conflict (key_hash, action) do nothing;

  select * into current_record
  from public.auth_rate_limits arl
  where arl.key_hash = p_key_hash and arl.action = p_action
  for update;

  if current_record.blocked_until is not null and current_record.blocked_until > now() then
    return false;
  end if;

  if current_record.window_started_at + window_interval <= now() then
    update public.auth_rate_limits
    set window_started_at = now(),
        attempt_count = 1,
        blocked_until = null,
        updated_at = now()
    where key_hash = p_key_hash and action = p_action;
    return true;
  end if;

  if current_record.attempt_count >= p_limit then
    update public.auth_rate_limits
    set blocked_until = current_record.window_started_at + window_interval,
        updated_at = now()
    where key_hash = p_key_hash and action = p_action;
    return false;
  end if;

  update public.auth_rate_limits
  set attempt_count = attempt_count + 1,
      updated_at = now()
  where key_hash = p_key_hash and action = p_action;
  return true;
end;
$$;

revoke all on function public.complete_student_activation(text, text, uuid, text)
  from public, anon, authenticated;
grant execute on function public.complete_student_activation(text, text, uuid, text)
  to service_role;

revoke all on function public.register_pending_teacher(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.register_pending_teacher(uuid, text, text)
  to service_role;

revoke all on function public.approve_pending_teacher(uuid, uuid, uuid[])
  from public, anon, authenticated;
grant execute on function public.approve_pending_teacher(uuid, uuid, uuid[])
  to authenticated;

revoke all on function public.admin_create_student(
  uuid, uuid, text, smallint, text, text, text, text, timestamptz
) from public, anon, authenticated;
grant execute on function public.admin_create_student(
  uuid, uuid, text, smallint, text, text, text, text, timestamptz
) to authenticated;

revoke all on function public.admin_update_student_settings(
  uuid, uuid, text, text, boolean, uuid[]
) from public, anon, authenticated;
grant execute on function public.admin_update_student_settings(
  uuid, uuid, text, text, boolean, uuid[]
) to authenticated;

revoke all on function public.admin_replace_student_activation(uuid, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.admin_replace_student_activation(uuid, text, timestamptz)
  to authenticated;

revoke all on function public.publish_contact_book_assignment(
  uuid, uuid, date, text, timestamptz, text, text
) from public, anon, authenticated;
grant execute on function public.publish_contact_book_assignment(
  uuid, uuid, date, text, timestamptz, text, text
) to authenticated;

revoke all on function public.record_assignment_submission_check(uuid, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.record_assignment_submission_check(uuid, text, text, jsonb)
  to authenticated;

revoke all on function public.consume_auth_rate_limit(text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.consume_auth_rate_limit(text, text, integer, integer)
  to service_role;

create or replace function public.contact_book_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.prepare_submission_exception()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.initial_reason in ('incomplete', 'not_brought') then
      new.counts_as_missing = true;
    elsif new.initial_reason = 'late' then
      new.counts_as_late = true;
    end if;
  end if;

  if new.workflow_state in ('made_up', 'waived') then
    new.resolved_at = coalesce(new.resolved_at, now());
    new.hide_after = coalesce(new.hide_after, new.resolved_at + interval '1 day');
  else
    new.resolved_at = null;
    new.hide_after = null;
  end if;

  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.log_submission_status_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.submission_status_events (
      submission_exception_id,
      from_reason,
      to_reason,
      from_state,
      to_state,
      counts_as_missing,
      counts_as_late,
      changed_by
    ) values (
      new.id,
      null,
      new.current_reason,
      null,
      new.workflow_state,
      new.counts_as_missing,
      new.counts_as_late,
      new.first_recorded_by
    );
  elsif old.current_reason is distinct from new.current_reason
     or old.workflow_state is distinct from new.workflow_state
     or old.counts_as_missing is distinct from new.counts_as_missing
     or old.counts_as_late is distinct from new.counts_as_late then
    insert into public.submission_status_events (
      submission_exception_id,
      from_reason,
      to_reason,
      from_state,
      to_state,
      counts_as_missing,
      counts_as_late,
      changed_by
    ) values (
      new.id,
      old.current_reason,
      new.current_reason,
      old.workflow_state,
      new.workflow_state,
      new.counts_as_missing,
      new.counts_as_late,
      new.last_updated_by
    );
  end if;

  return new;
end;
$$;

drop trigger if exists classes_set_updated_at on public.classes;
create trigger classes_set_updated_at
before update on public.classes
for each row execute function public.contact_book_set_updated_at();

drop trigger if exists profiles_set_updated_at on public.contact_book_profiles;
create trigger profiles_set_updated_at
before update on public.contact_book_profiles
for each row execute function public.contact_book_set_updated_at();

drop trigger if exists students_set_updated_at on public.students;
create trigger students_set_updated_at
before update on public.students
for each row execute function public.contact_book_set_updated_at();

drop trigger if exists assignments_set_updated_at on public.assignments;
create trigger assignments_set_updated_at
before update on public.assignments
for each row execute function public.contact_book_set_updated_at();

drop trigger if exists submission_exceptions_prepare on public.submission_exceptions;
create trigger submission_exceptions_prepare
before insert or update on public.submission_exceptions
for each row execute function public.prepare_submission_exception();

drop trigger if exists submission_exceptions_log_event on public.submission_exceptions;
create trigger submission_exceptions_log_event
after insert or update on public.submission_exceptions
for each row execute function public.log_submission_status_event();

drop trigger if exists announcements_set_updated_at on public.announcements;
create trigger announcements_set_updated_at
before update on public.announcements
for each row execute function public.contact_book_set_updated_at();

drop trigger if exists honor_entries_set_updated_at on public.honor_entries;
create trigger honor_entries_set_updated_at
before update on public.honor_entries
for each row execute function public.contact_book_set_updated_at();

drop trigger if exists student_scores_set_updated_at on public.student_scores;
create trigger student_scores_set_updated_at
before update on public.student_scores
for each row execute function public.contact_book_set_updated_at();
