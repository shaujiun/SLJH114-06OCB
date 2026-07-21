-- 建立八年六班參照資料與教師核准交易函式。
-- 不包含學生姓名、學號或任何測試帳號。

begin;

insert into public.schools (name)
values ('雲林縣立石榴國民中學')
on conflict (name) do nothing;

insert into public.academic_years (school_id, school_year, starts_on, ends_on)
select id, 115, date '2026-08-01', date '2027-07-31'
from public.schools
where name = '雲林縣立石榴國民中學'
on conflict (school_id, school_year) do nothing;

insert into public.academic_terms (academic_year_id, semester, starts_on, ends_on)
select id, 1, date '2026-08-01', date '2027-01-31'
from public.academic_years
where school_year = 115
on conflict (academic_year_id, semester) do nothing;

insert into public.academic_terms (academic_year_id, semester, starts_on, ends_on)
select id, 2, date '2027-02-01', date '2027-07-31'
from public.academic_years
where school_year = 115
on conflict (academic_year_id, semester) do nothing;

insert into public.classes (academic_year_id, grade_level, class_number, name)
select id, 8, 6, '八年六班'
from public.academic_years
where school_year = 115
on conflict (academic_year_id, name) do nothing;

insert into public.subjects (school_id, code, name)
select s.id, v.code, v.name
from public.schools s
cross join (
  values
    ('chinese', '國文'),
    ('english', '英語'),
    ('math', '數學'),
    ('science', '自然'),
    ('social', '社會'),
    ('health_pe', '健體'),
    ('arts', '藝文'),
    ('integrative', '綜合'),
    ('other', '其他')
) as v(code, name)
where s.name = '雲林縣立石榴國民中學'
on conflict (school_id, code) do nothing;

insert into public.class_subjects (class_id, subject_id, sort_order)
select c.id, s.id,
  case s.code::text
    when 'chinese' then 10
    when 'english' then 20
    when 'math' then 30
    when 'science' then 40
    when 'social' then 50
    when 'health_pe' then 60
    when 'arts' then 70
    when 'integrative' then 80
    else 90
  end
from public.classes c
join public.academic_years ay on ay.id = c.academic_year_id and ay.school_year = 115
join public.subjects s on true
join public.schools school on school.id = s.school_id
  and school.name = '雲林縣立石榴國民中學'
where c.name = '八年六班'
on conflict (class_id, subject_id) do nothing;

insert into public.class_staff_assignments (
  class_id,
  profile_id,
  role,
  class_subject_id,
  starts_on,
  created_by
)
select
  c.id,
  p.id,
  'homeroom_teacher',
  null,
  date '2026-08-01',
  p.id
from public.classes c
join public.academic_years ay
  on ay.id = c.academic_year_id and ay.school_year = 115
cross join public.contact_book_profiles p
where c.name = '八年六班'
  and p.user_type = 'admin'
  and p.approval_status = 'approved'
  and p.is_active
on conflict do nothing;

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

revoke all on function public.approve_pending_teacher(uuid, uuid, uuid[])
  from public, anon, authenticated;
grant execute on function public.approve_pending_teacher(uuid, uuid, uuid[])
  to authenticated;

commit;
