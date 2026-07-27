-- Add separate social-studies subjects for daily quiz reminders.
-- Keep the existing Social Studies subject active so earlier assignments and
-- teacher permissions remain intact.

begin;

insert into public.subjects (school_id, code, name)
select school.id, subject_data.code, subject_data.name
from public.schools school
cross join (
  values
    ('history', '歷史'),
    ('geography', '地理'),
    ('civics', '公民')
) as subject_data(code, name)
where school.name = '雲林縣立石榴國民中學'
on conflict (school_id, code) do update
set name = excluded.name;

insert into public.class_subjects (
  class_id,
  subject_id,
  sort_order,
  is_active
)
select
  class.id,
  subject.id,
  case subject.code::text
    when 'history' then 51
    when 'geography' then 52
    when 'civics' then 53
  end,
  true
from public.classes class
join public.academic_years academic_year
  on academic_year.id = class.academic_year_id
  and academic_year.school_year = 115
join public.schools school
  on school.id = academic_year.school_id
  and school.name = '雲林縣立石榴國民中學'
join public.subjects subject
  on subject.school_id = school.id
  and subject.code in ('history', 'geography', 'civics')
where class.name = '八年六班'
on conflict (class_id, subject_id) do update
set sort_order = excluded.sort_order,
    is_active = true;

commit;
