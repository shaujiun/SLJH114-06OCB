-- 八年六班初始資料。
-- 三學期日期依石榴國中 115 學年度區間設定。

insert into public.schools (name)
values ('雲林縣立石榴國民中學')
on conflict (name) do nothing;

insert into public.academic_years (school_id, school_year, starts_on, ends_on)
select id, 115, date '2026-08-01', date '2027-07-31'
from public.schools
where name = '雲林縣立石榴國民中學'
on conflict (school_id, school_year) do nothing;

insert into public.academic_terms (academic_year_id, semester, starts_on, ends_on)
select id, 1, date '2026-08-10', date '2026-11-15'
from public.academic_years
where school_year = 115
on conflict (academic_year_id, semester) do update
set starts_on = excluded.starts_on,
    ends_on = excluded.ends_on;

insert into public.academic_terms (academic_year_id, semester, starts_on, ends_on)
select id, 2, date '2026-11-30', date '2027-03-14'
from public.academic_years
where school_year = 115
on conflict (academic_year_id, semester) do update
set starts_on = excluded.starts_on,
    ends_on = excluded.ends_on;

insert into public.academic_terms (academic_year_id, semester, starts_on, ends_on)
select id, 3, date '2027-03-22', date '2027-06-20'
from public.academic_years
where school_year = 115
on conflict (academic_year_id, semester) do update
set starts_on = excluded.starts_on,
    ends_on = excluded.ends_on;

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
join public.schools school on school.id = s.school_id and school.name = '雲林縣立石榴國民中學'
where c.name = '八年六班'
on conflict (class_id, subject_id) do nothing;

-- 將目前已核准的管理員設定為八年六班導師。
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
