-- Student helpers may work in the current term or pre-test the single next
-- upcoming term. Later future terms and completed terms remain read-only.

create or replace function public.can_publish_subject_for_term(
  target_class_subject_id uuid,
  target_academic_term_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.can_manage_subject(target_class_subject_id)
  or exists (
    select 1
    from public.student_helper_assignments sha
    join public.students s on s.id = sha.student_id
    join public.contact_book_profiles p on p.id = s.profile_id
    join public.academic_terms term on term.id = sha.academic_term_id
    where sha.class_subject_id = target_class_subject_id
      and sha.academic_term_id = target_academic_term_id
      and sha.helper_role = 'subject_helper'
      and s.profile_id = auth.uid()
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
      and sha.starts_on <= greatest(current_date, term.starts_on)
      and (sha.ends_on is null or sha.ends_on >= greatest(current_date, term.starts_on))
      and s.is_active
      and p.approval_status = 'approved'
      and p.is_active
  )
  or exists (
    select 1
    from public.student_helper_assignments sha
    join public.students s on s.id = sha.student_id
    join public.contact_book_profiles p on p.id = s.profile_id
    join public.academic_terms term on term.id = sha.academic_term_id
    join public.class_subjects cs on cs.id = target_class_subject_id
      and cs.class_id = s.class_id
    where sha.academic_term_id = target_academic_term_id
      and sha.helper_role = 'homework_leader'
      and sha.class_subject_id is null
      and s.profile_id = auth.uid()
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
      and sha.starts_on <= greatest(current_date, term.starts_on)
      and (sha.ends_on is null or sha.ends_on >= greatest(current_date, term.starts_on))
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
    join public.academic_terms term on term.id = sha.academic_term_id
    join public.contact_book_profiles p on p.id = s.profile_id
    where s.profile_id = auth.uid()
      and s.class_id = target_class_id
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
      and sha.starts_on <= greatest(current_date, term.starts_on)
      and (sha.ends_on is null or sha.ends_on >= greatest(current_date, term.starts_on))
      and s.is_active
      and p.approval_status = 'approved'
      and p.is_active
  );
$$;
