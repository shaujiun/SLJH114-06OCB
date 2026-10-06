begin;

alter table public.admission_self_checks
  add column if not exists semester_records jsonb not null default '[]'::jsonb,
  add column if not exists balanced_scores jsonb not null default '[]'::jsonb,
  add column if not exists fitness_gender text,
  add column if not exists fitness_records jsonb not null default '[]'::jsonb;

alter table public.admission_self_checks
  drop constraint if exists admission_self_checks_semester_records_check,
  drop constraint if exists admission_self_checks_balanced_scores_check,
  drop constraint if exists admission_self_checks_fitness_gender_check,
  drop constraint if exists admission_self_checks_fitness_records_check;

alter table public.admission_self_checks
  add constraint admission_self_checks_semester_records_check check (
    jsonb_typeof(semester_records) = 'array'
    and jsonb_array_length(semester_records) <= 5
    and octet_length(semester_records::text) <= 12000
  ),
  add constraint admission_self_checks_balanced_scores_check check (
    jsonb_typeof(balanced_scores) = 'array'
    and jsonb_array_length(balanced_scores) <= 5
    and octet_length(balanced_scores::text) <= 12000
  ),
  add constraint admission_self_checks_fitness_gender_check check (
    fitness_gender is null or fitness_gender in ('male', 'female')
  ),
  add constraint admission_self_checks_fitness_records_check check (
    jsonb_typeof(fitness_records) = 'array'
    and jsonb_array_length(fitness_records) <= 5
    and octet_length(fitness_records::text) <= 16000
  );

create or replace function public.save_my_admission_self_check(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_student public.students%rowtype;
  target_id uuid;
  normalized_domains jsonb;
  normalized_semester_records jsonb;
  normalized_balanced_scores jsonb;
  normalized_fitness_records jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select student.* into target_student
  from public.students student
  join public.contact_book_profiles profile on profile.id = student.profile_id
  where student.profile_id = auth.uid()
    and student.is_active
    and profile.approval_status = 'approved'
    and profile.is_active;
  if not found then raise exception 'student_required' using errcode = '42501'; end if;
  if jsonb_typeof(coalesce(p_payload, 'null'::jsonb)) <> 'object' then
    raise exception 'invalid_admission_check';
  end if;
  if p_payload ? 'balancedDomains'
    and jsonb_typeof(p_payload->'balancedDomains') <> 'array' then
    raise exception 'invalid_admission_check';
  end if;
  if p_payload ? 'semesterRecords'
    and (jsonb_typeof(p_payload->'semesterRecords') <> 'array'
      or jsonb_array_length(p_payload->'semesterRecords') > 5) then
    raise exception 'invalid_admission_check';
  end if;
  if p_payload ? 'balancedScores'
    and (jsonb_typeof(p_payload->'balancedScores') <> 'array'
      or jsonb_array_length(p_payload->'balancedScores') > 5) then
    raise exception 'invalid_admission_check';
  end if;
  if p_payload ? 'fitnessRecords'
    and (jsonb_typeof(p_payload->'fitnessRecords') <> 'array'
      or jsonb_array_length(p_payload->'fitnessRecords') > 5) then
    raise exception 'invalid_admission_check';
  end if;
  if nullif(p_payload->>'fitnessGender', '') is not null
    and p_payload->>'fitnessGender' not in ('male', 'female') then
    raise exception 'invalid_admission_check';
  end if;

  select coalesce(jsonb_agg(domain order by domain), '[]'::jsonb)
  into normalized_domains
  from (
    select distinct value as domain
    from jsonb_array_elements_text(coalesce(p_payload->'balancedDomains', '[]'::jsonb))
    where value in ('health', 'arts', 'integrated', 'technology')
  ) allowed_domains;

  normalized_semester_records := coalesce(p_payload->'semesterRecords', '[]'::jsonb);
  normalized_balanced_scores := coalesce(p_payload->'balancedScores', '[]'::jsonb);
  normalized_fitness_records := coalesce(p_payload->'fitnessRecords', '[]'::jsonb);

  insert into public.admission_self_checks (
    student_id, class_id, rule_version, preference_order,
    economic_weakness, nearby_enrollment, no_truancy_semesters,
    discipline_status, semester_records, balanced_domains, balanced_scores,
    remote_school_band, major_merits, minor_merits, commendations,
    fitness_qualified_items, fitness_gender, fitness_records,
    review_status, reviewed_by, reviewed_at
  ) values (
    target_student.id,
    target_student.class_id,
    'yunlin-113-05-16',
    nullif(p_payload->>'preferenceOrder', '')::smallint,
    nullif(p_payload->>'economicWeakness', '')::boolean,
    nullif(p_payload->>'nearbyEnrollment', '')::boolean,
    coalesce(nullif(p_payload->>'noTruancySemesters', '')::smallint, 0),
    nullif(p_payload->>'disciplineStatus', ''),
    normalized_semester_records,
    normalized_domains,
    normalized_balanced_scores,
    nullif(p_payload->>'remoteSchoolBand', ''),
    coalesce(nullif(p_payload->>'majorMerits', '')::smallint, 0),
    coalesce(nullif(p_payload->>'minorMerits', '')::smallint, 0),
    coalesce(nullif(p_payload->>'commendations', '')::smallint, 0),
    coalesce(nullif(p_payload->>'fitnessQualifiedItems', '')::smallint, 0),
    nullif(p_payload->>'fitnessGender', ''),
    normalized_fitness_records,
    'self_reported', null, null
  )
  on conflict (student_id) do update
  set preference_order = excluded.preference_order,
      economic_weakness = excluded.economic_weakness,
      nearby_enrollment = excluded.nearby_enrollment,
      no_truancy_semesters = excluded.no_truancy_semesters,
      discipline_status = excluded.discipline_status,
      semester_records = case when p_payload ? 'semesterRecords' then excluded.semester_records else admission_self_checks.semester_records end,
      balanced_domains = excluded.balanced_domains,
      balanced_scores = case when p_payload ? 'balancedScores' then excluded.balanced_scores else admission_self_checks.balanced_scores end,
      remote_school_band = excluded.remote_school_band,
      major_merits = excluded.major_merits,
      minor_merits = excluded.minor_merits,
      commendations = excluded.commendations,
      fitness_qualified_items = excluded.fitness_qualified_items,
      fitness_gender = case when p_payload ? 'fitnessGender' then excluded.fitness_gender else admission_self_checks.fitness_gender end,
      fitness_records = case when p_payload ? 'fitnessRecords' then excluded.fitness_records else admission_self_checks.fitness_records end,
      review_status = 'self_reported',
      reviewed_by = null,
      reviewed_at = null,
      updated_at = now()
  returning id into target_id;

  return target_id;
exception
  when check_violation or invalid_text_representation or numeric_value_out_of_range then
    raise exception 'invalid_admission_check';
end;
$$;

revoke all on function public.save_my_admission_self_check(jsonb) from public, anon, authenticated;
grant execute on function public.save_my_admission_self_check(jsonb) to authenticated;

commit;
