-- Approved teachers need to test the contact book before the school year
-- starts. A scheduled assignment becomes usable from the later of today and
-- the academic-year start date, while expired assignments remain blocked.

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
    join public.classes c on c.id = csa.class_id
    join public.academic_years ay on ay.id = c.academic_year_id
    where csa.class_id = target_class_id
      and csa.profile_id = auth.uid()
      and csa.role = 'homeroom_teacher'
      and csa.starts_on <= greatest(current_date, ay.starts_on)
      and (csa.ends_on is null or csa.ends_on >= greatest(current_date, ay.starts_on))
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
    join public.classes c on c.id = csa.class_id
    join public.academic_years ay on ay.id = c.academic_year_id
    where csa.class_subject_id = target_class_subject_id
      and csa.profile_id = auth.uid()
      and csa.role = 'subject_teacher'
      and csa.starts_on <= greatest(current_date, ay.starts_on)
      and (csa.ends_on is null or csa.ends_on >= greatest(current_date, ay.starts_on))
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;

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
    join public.classes c on c.id = csa.class_id
    join public.academic_years ay on ay.id = c.academic_year_id
    where csa.class_id = target_class_id
      and csa.profile_id = auth.uid()
      and csa.starts_on <= greatest(current_date, ay.starts_on)
      and (csa.ends_on is null or csa.ends_on >= greatest(current_date, ay.starts_on))
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
    join public.classes c on c.id = csa.class_id
    join public.academic_years ay on ay.id = c.academic_year_id
    where csa.class_id = target_class_id
      and csa.profile_id = auth.uid()
      and csa.starts_on <= greatest(current_date, ay.starts_on)
      and (csa.ends_on is null or csa.ends_on >= greatest(current_date, ay.starts_on))
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
