-- 石榴國中採三學期制，調整限制並套用 115 學年度正式區間。

begin;

alter table public.academic_terms
  drop constraint if exists academic_terms_semester_check;

alter table public.academic_terms
  add constraint academic_terms_semester_check
  check (semester between 1 and 3);

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

commit;
