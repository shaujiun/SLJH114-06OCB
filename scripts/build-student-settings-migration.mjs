import { mkdir, readFile, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const projectDirectory = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const schema = await readFile(resolve(projectDirectory, 'supabase/schema.sql'), 'utf8')
const policies = await readFile(resolve(projectDirectory, 'supabase/rls-policies.sql'), 'utf8')

function between(source, start, end) {
  const startIndex = source.indexOf(start)
  const endIndex = source.indexOf(end, startIndex)
  if (startIndex < 0 || endIndex < 0) throw new Error(`Unable to extract SQL section: ${start}`)
  return source.slice(startIndex, endIndex).trim()
}

const managementFunctions = between(
  schema,
  'create or replace function public.admin_update_student_settings(',
  'create or replace function public.consume_auth_rate_limit(',
)
const managementGrants = between(
  schema,
  'revoke all on function public.admin_update_student_settings(',
  'revoke all on function public.consume_auth_rate_limit(',
)
const helperFunctions = between(
  policies,
  'create or replace function public.is_subject_helper(',
  'create or replace function public.can_view_class(',
)
const helperPolicies = between(
  policies,
  'create policy helper_read_self_or_staff',
  'create policy groups_read_allowed',
)

const migration = `-- 學生分組調整、作業長／小老師與啟用碼重發。

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

${managementFunctions}

${managementGrants}

${helperFunctions}

drop policy if exists helper_read_self_or_staff on public.student_helper_assignments;
drop policy if exists helper_staff_all on public.student_helper_assignments;

${helperPolicies}

commit;
`

const migrationPath = resolve(
  projectDirectory,
  'supabase/migrations/20260719113000_add_student_settings_and_helpers.sql',
)
await mkdir(dirname(migrationPath), { recursive: true })
await writeFile(migrationPath, migration, 'utf8')
console.log(`Built ${migrationPath}`)
