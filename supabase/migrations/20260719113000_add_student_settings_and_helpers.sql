-- 學生分組調整、作業長／小老師與啟用碼重發。

begin;

drop index if exists public.active_helper_assignment_unique;

alter table public.student_helper_assignments
  add column if not exists academic_term_id uuid references public.academic_terms(id) on delete cascade;

update public.student_helper_assignments sha
set academic_term_id = term.id
from public.students student
join public.classes class on class.id = student.class_id
join public.academic_terms term on term.academic_year_id = class.academic_year_id
where sha.student_id = student.id
  and sha.academic_term_id is null
  and sha.starts_on between term.starts_on and term.ends_on;

do $$
begin
  if exists (
    select 1 from public.student_helper_assignments where academic_term_id is null
  ) then
    raise exception 'unable_to_map_existing_helper_term';
  end if;
end;
$$;

alter table public.student_helper_assignments
  alter column academic_term_id set not null,
  alter column class_subject_id drop not null;

alter table public.student_helper_assignments
  drop constraint if exists helper_subject_role_valid;
alter table public.student_helper_assignments
  add constraint helper_subject_role_valid check (
    (helper_role = 'homework_leader' and class_subject_id is null)
    or (helper_role = 'subject_helper' and class_subject_id is not null)
  );

create unique index if not exists helper_assignment_term_unique
  on public.student_helper_assignments(
    student_id,
    academic_term_id,
    helper_role,
    coalesce(class_subject_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

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

drop policy if exists helper_read_self_or_staff on public.student_helper_assignments;
drop policy if exists helper_staff_all on public.student_helper_assignments;

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

commit;
