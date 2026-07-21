-- 線上聯絡簿：RLS 權限草案
-- 必須在 schema.sql 之後執行。正式執行前仍需以各角色測試帳號驗證。

create or replace function public.is_approved_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.contact_book_profiles p
    where p.id = auth.uid()
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;

create or replace function public.contact_book_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.contact_book_profiles p
    where p.id = auth.uid()
      and p.user_type = 'admin'
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;

create or replace function public.is_student_self(target_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.students s
    join public.contact_book_profiles p on p.id = s.profile_id
    where s.id = target_student_id
      and s.profile_id = auth.uid()
      and s.is_active
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;

create or replace function public.current_student_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select s.id
  from public.students s
  where s.profile_id = auth.uid() and s.is_active
  limit 1;
$$;

create or replace function public.can_manage_class(target_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.contact_book_is_admin() or exists (
    select 1
    from public.class_staff_assignments csa
    join public.contact_book_profiles p on p.id = csa.profile_id
    where csa.class_id = target_class_id
      and csa.profile_id = auth.uid()
      and csa.role = 'homeroom_teacher'
      and csa.starts_on <= current_date
      and (csa.ends_on is null or csa.ends_on >= current_date)
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;

create or replace function public.can_manage_subject(target_class_subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.class_subjects cs
    where cs.id = target_class_subject_id
      and public.can_manage_class(cs.class_id)
  ) or exists (
    select 1
    from public.class_staff_assignments csa
    join public.contact_book_profiles p on p.id = csa.profile_id
    where csa.class_subject_id = target_class_subject_id
      and csa.profile_id = auth.uid()
      and csa.role = 'subject_teacher'
      and csa.starts_on <= current_date
      and (csa.ends_on is null or csa.ends_on >= current_date)
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;

create or replace function public.is_subject_helper(target_class_subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.student_helper_assignments sha
    join public.students s on s.id = sha.student_id
    join public.contact_book_profiles p on p.id = s.profile_id
    where sha.class_subject_id = target_class_subject_id
      and sha.helper_role = 'subject_helper'
      and s.profile_id = auth.uid()
      and sha.starts_on <= current_date
      and (sha.ends_on is null or sha.ends_on >= current_date)
      and s.is_active
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;

create or replace function public.is_homework_leader(target_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.student_helper_assignments sha
    join public.students s on s.id = sha.student_id
    join public.contact_book_profiles p on p.id = s.profile_id
    where s.class_id = target_class_id
      and s.profile_id = auth.uid()
      and sha.helper_role = 'homework_leader'
      and sha.class_subject_id is null
      and sha.starts_on <= current_date
      and (sha.ends_on is null or sha.ends_on >= current_date)
      and s.is_active
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;

create or replace function public.can_publish_subject(target_class_subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_manage_subject(target_class_subject_id)
      or public.is_subject_helper(target_class_subject_id)
      or exists (
        select 1 from public.class_subjects cs
        where cs.id = target_class_subject_id
          and public.is_homework_leader(cs.class_id)
      );
$$;

-- 透過 security definer 函式讀取對象快照，避免 assignments 與
-- assignment_recipients 的 RLS 規則互相遞迴。
create or replace function public.is_current_student_assignment_recipient(
  target_assignment_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.assignment_recipients ar
    where ar.assignment_id = target_assignment_id
      and ar.student_id = public.current_student_id()
  );
$$;

create or replace function public.can_read_assignment_recipients_as_staff(
  target_assignment_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.assignments a
    where a.id = target_assignment_id
      and public.can_publish_subject(a.class_subject_id)
  );
$$;

revoke all on function public.is_current_student_assignment_recipient(uuid)
  from public, anon, authenticated;
grant execute on function public.is_current_student_assignment_recipient(uuid)
  to authenticated;

revoke all on function public.can_read_assignment_recipients_as_staff(uuid)
  from public, anon, authenticated;
grant execute on function public.can_read_assignment_recipients_as_staff(uuid)
  to authenticated;

create or replace function public.can_view_class(target_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_manage_class(target_class_id) or exists (
    select 1
    from public.class_staff_assignments csa
    join public.contact_book_profiles p on p.id = csa.profile_id
    where csa.class_id = target_class_id
      and csa.profile_id = auth.uid()
      and csa.starts_on <= current_date
      and (csa.ends_on is null or csa.ends_on >= current_date)
      and p.approval_status = 'approved'
      and p.is_active
  ) or exists (
    select 1
    from public.students s
    join public.contact_book_profiles p on p.id = s.profile_id
    where s.class_id = target_class_id
      and s.profile_id = auth.uid()
      and s.is_active
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;

create or replace function public.can_view_class_roster(target_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_manage_class(target_class_id) or exists (
    select 1
    from public.class_staff_assignments csa
    join public.contact_book_profiles p on p.id = csa.profile_id
    where csa.class_id = target_class_id
      and csa.profile_id = auth.uid()
      and csa.starts_on <= current_date
      and (csa.ends_on is null or csa.ends_on >= current_date)
      and p.approval_status = 'approved'
      and p.is_active
  ) or exists (
    select 1
    from public.student_helper_assignments sha
    join public.students s on s.id = sha.student_id
    join public.class_subjects cs on cs.id = sha.class_subject_id
    join public.contact_book_profiles p on p.id = s.profile_id
    where s.profile_id = auth.uid()
      and cs.class_id = target_class_id
      and sha.starts_on <= current_date
      and (sha.ends_on is null or sha.ends_on >= current_date)
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;

alter table public.schools enable row level security;
alter table public.academic_years enable row level security;
alter table public.academic_terms enable row level security;
alter table public.classes enable row level security;
alter table public.contact_book_profiles enable row level security;
alter table public.students enable row level security;
alter table public.student_activation_codes enable row level security;
alter table public.auth_rate_limits enable row level security;
alter table public.subjects enable row level security;
alter table public.class_subjects enable row level security;
alter table public.class_staff_assignments enable row level security;
alter table public.student_helper_assignments enable row level security;
alter table public.student_subject_groups enable row level security;
alter table public.assignments enable row level security;
alter table public.assignment_recipients enable row level security;
alter table public.submission_checks enable row level security;
alter table public.submission_exceptions enable row level security;
alter table public.submission_status_events enable row level security;
alter table public.announcements enable row level security;
alter table public.announcement_reads enable row level security;
alter table public.honor_entries enable row level security;
alter table public.assessment_periods enable row level security;
alter table public.assessments enable row level security;
alter table public.student_scores enable row level security;

create policy contact_book_profiles_read_self on public.contact_book_profiles
for select to authenticated using (id = auth.uid() or public.contact_book_is_admin());

create policy contact_book_profiles_admin_update on public.contact_book_profiles
for update to authenticated
using (public.contact_book_is_admin())
with check (public.contact_book_is_admin());

create policy students_read_allowed on public.students
for select to authenticated using (
  public.is_student_self(id)
  or public.can_view_class_roster(class_id)
);

create policy students_admin_all on public.students
for all to authenticated
using (public.can_manage_class(class_id))
with check (public.can_manage_class(class_id));

create policy activation_codes_admin_all on public.student_activation_codes
for all to authenticated
using (
  exists (
    select 1 from public.students s
    where s.id = student_id and public.can_manage_class(s.class_id)
  )
)
with check (
  exists (
    select 1 from public.students s
    where s.id = student_id and public.can_manage_class(s.class_id)
  )
);

create policy staff_read_self_or_admin on public.class_staff_assignments
for select to authenticated using (
  profile_id = auth.uid() or public.can_manage_class(class_id)
);

create policy staff_admin_all on public.class_staff_assignments
for all to authenticated
using (public.can_manage_class(class_id))
with check (public.can_manage_class(class_id));

create policy helper_read_self_or_staff on public.student_helper_assignments
for select to authenticated using (
  public.is_student_self(student_id)
  or (class_subject_id is not null and public.can_manage_subject(class_subject_id))
  or exists (
    select 1 from public.students s
    where s.id = student_id and public.can_manage_class(s.class_id)
  )
);

create policy helper_staff_all on public.student_helper_assignments
for all to authenticated
using (
  (class_subject_id is not null and public.can_manage_subject(class_subject_id))
  or exists (
    select 1 from public.students s
    where s.id = student_id and public.can_manage_class(s.class_id)
  )
)
with check (
  (class_subject_id is not null and public.can_manage_subject(class_subject_id))
  or exists (
    select 1 from public.students s
    where s.id = student_id and public.can_manage_class(s.class_id)
  )
);

create policy groups_read_allowed on public.student_subject_groups
for select to authenticated using (
  public.is_student_self(student_id)
  or public.can_manage_subject(class_subject_id)
);

create policy groups_staff_all on public.student_subject_groups
for all to authenticated
using (public.can_manage_subject(class_subject_id))
with check (public.can_manage_subject(class_subject_id));

create policy assignments_read_allowed on public.assignments
for select to authenticated using (
  public.can_publish_subject(class_subject_id)
  or (is_active and public.is_current_student_assignment_recipient(id))
);

create policy assignments_publish on public.assignments
for insert to authenticated with check (
  public.can_publish_subject(class_subject_id)
  and published_by = auth.uid()
);

create policy assignments_update_staff_or_owner_helper on public.assignments
for update to authenticated using (
  public.can_manage_subject(class_subject_id)
  or (public.is_subject_helper(class_subject_id) and published_by = auth.uid())
)
with check (
  public.can_manage_subject(class_subject_id)
  or (public.is_subject_helper(class_subject_id) and published_by = auth.uid())
);

create policy recipients_read_allowed on public.assignment_recipients
for select to authenticated using (
  public.is_student_self(student_id)
  or public.can_read_assignment_recipients_as_staff(assignment_id)
);

create policy submission_checks_read_allowed on public.submission_checks
for select to authenticated using (
  exists (
    select 1 from public.assignments a
    where a.id = assignment_id and public.can_publish_subject(a.class_subject_id)
  )
);

create policy submission_checks_insert_allowed on public.submission_checks
for insert to authenticated with check (
  checked_by = auth.uid()
  and exists (
    select 1 from public.assignments a
    where a.id = assignment_id and public.can_publish_subject(a.class_subject_id)
  )
);

create policy exceptions_read_allowed on public.submission_exceptions
for select to authenticated using (
  public.is_student_self(student_id)
  or exists (
    select 1 from public.assignments a
    where a.id = assignment_id and public.can_publish_subject(a.class_subject_id)
  )
);

create policy exceptions_insert_allowed on public.submission_exceptions
for insert to authenticated with check (
  first_recorded_by = auth.uid()
  and last_updated_by = auth.uid()
  and exists (
    select 1 from public.assignments a
    where a.id = assignment_id and public.can_publish_subject(a.class_subject_id)
  )
);

create policy exceptions_teacher_update on public.submission_exceptions
for update to authenticated using (
  exists (
    select 1 from public.assignments a
    where a.id = assignment_id and public.can_manage_subject(a.class_subject_id)
  )
)
with check (
  last_updated_by = auth.uid()
  and exists (
    select 1 from public.assignments a
    where a.id = assignment_id and public.can_manage_subject(a.class_subject_id)
  )
);

create policy exception_events_read_allowed on public.submission_status_events
for select to authenticated using (
  exists (
    select 1
    from public.submission_exceptions se
    join public.assignments a on a.id = se.assignment_id
    where se.id = submission_exception_id
      and (
        public.is_student_self(se.student_id)
        or public.can_publish_subject(a.class_subject_id)
      )
  )
);

create policy announcements_read_class on public.announcements
for select to authenticated using (
  (is_active and public.can_view_class(class_id))
  or public.can_manage_class(class_id)
);

create policy announcements_admin_all on public.announcements
for all to authenticated
using (public.can_manage_class(class_id))
with check (public.can_manage_class(class_id) and published_by = auth.uid());

create policy announcement_reads_read_allowed on public.announcement_reads
for select to authenticated using (
  public.is_student_self(student_id)
  or exists (
    select 1 from public.announcements a
    where a.id = announcement_id and public.can_manage_class(a.class_id)
  )
);

create policy announcement_reads_student_insert on public.announcement_reads
for insert to authenticated with check (public.is_student_self(student_id));

create policy honor_read_class on public.honor_entries
for select to authenticated using (
  (is_visible and public.can_view_class(class_id))
  or public.can_manage_class(class_id)
);

create policy honor_admin_all on public.honor_entries
for all to authenticated
using (public.can_manage_class(class_id))
with check (public.can_manage_class(class_id) and created_by = auth.uid());

create policy scores_read_allowed on public.student_scores
for select to authenticated using (
  public.is_student_self(student_id)
  or exists (
    select 1
    from public.assessments a
    where a.id = assessment_id
      and public.can_manage_subject(a.class_subject_id)
  )
);

-- 參照資料採已核准使用者唯讀；建立與修改將由導師管理流程處理。
create policy schools_read_approved on public.schools
for select to authenticated using (public.is_approved_user());

create policy academic_years_read_approved on public.academic_years
for select to authenticated using (public.is_approved_user());

create policy academic_terms_read_approved on public.academic_terms
for select to authenticated using (public.is_approved_user());

create policy classes_read_allowed on public.classes
for select to authenticated using (public.can_view_class(id));

create policy subjects_read_approved on public.subjects
for select to authenticated using (public.is_approved_user());

create policy class_subjects_read_class on public.class_subjects
for select to authenticated using (public.can_view_class(class_id));

create policy subjects_admin_all on public.subjects
for all to authenticated
using (public.contact_book_is_admin())
with check (public.contact_book_is_admin());

create policy class_subjects_admin_all on public.class_subjects
for all to authenticated
using (public.can_manage_class(class_id))
with check (public.can_manage_class(class_id));
