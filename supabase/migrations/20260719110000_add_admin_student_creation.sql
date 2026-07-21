-- 管理員以單一交易建立學生、數英分組與啟用碼雜湊。

begin;

create or replace function public.admin_create_student(
  p_class_id uuid,
  p_academic_term_id uuid,
  p_student_id_code text,
  p_seat_number smallint,
  p_full_name text,
  p_math_group text,
  p_english_group text,
  p_code_hash text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  created_student public.students%rowtype;
  math_class_subject_id uuid;
  english_class_subject_id uuid;
  group_effective_from date;
begin
  if not public.contact_book_is_admin() then
    raise exception 'admin_required' using errcode = '42501';
  end if;

  if trim(p_student_id_code) !~ '^[0-9]{4,20}$'
    or p_seat_number < 1
    or p_seat_number > 99
    or char_length(trim(p_full_name)) < 2
    or char_length(trim(p_full_name)) > 50
    or upper(trim(p_math_group)) not in ('A', 'B')
    or upper(trim(p_english_group)) not in ('A', 'B')
    or p_code_hash !~ '^[0-9a-f]{64}$'
    or p_expires_at <= now() then
    raise exception 'invalid_student_data';
  end if;

  select term.starts_on
  into group_effective_from
  from public.classes c
  join public.academic_terms term
    on term.academic_year_id = c.academic_year_id
  where c.id = p_class_id
    and c.is_active
    and term.id = p_academic_term_id;

  if group_effective_from is null then
    raise exception 'invalid_class_term';
  end if;

  select cs.id into math_class_subject_id
  from public.class_subjects cs
  join public.subjects s on s.id = cs.subject_id
  where cs.class_id = p_class_id
    and cs.is_active
    and s.code = 'math';

  select cs.id into english_class_subject_id
  from public.class_subjects cs
  join public.subjects s on s.id = cs.subject_id
  where cs.class_id = p_class_id
    and cs.is_active
    and s.code = 'english';

  if math_class_subject_id is null or english_class_subject_id is null then
    raise exception 'required_subject_missing';
  end if;

  insert into public.students (
    class_id,
    student_id_code,
    seat_number,
    full_name
  ) values (
    p_class_id,
    trim(p_student_id_code),
    p_seat_number,
    trim(p_full_name)
  )
  returning * into created_student;

  insert into public.student_subject_groups (
    student_id,
    class_subject_id,
    academic_term_id,
    group_code,
    effective_from,
    created_by
  ) values
    (
      created_student.id,
      math_class_subject_id,
      p_academic_term_id,
      upper(trim(p_math_group)),
      group_effective_from,
      auth.uid()
    ),
    (
      created_student.id,
      english_class_subject_id,
      p_academic_term_id,
      upper(trim(p_english_group)),
      group_effective_from,
      auth.uid()
    );

  insert into public.student_activation_codes (
    student_id,
    code_hash,
    expires_at,
    created_by
  ) values (
    created_student.id,
    p_code_hash,
    p_expires_at,
    auth.uid()
  );

  return jsonb_build_object(
    'id', created_student.id,
    'studentIdCode', created_student.student_id_code,
    'seatNumber', created_student.seat_number,
    'fullName', created_student.full_name,
    'mathGroup', upper(trim(p_math_group)),
    'englishGroup', upper(trim(p_english_group))
  );
end;
$$;

revoke all on function public.admin_create_student(
  uuid, uuid, text, smallint, text, text, text, text, timestamptz
) from public, anon, authenticated;
grant execute on function public.admin_create_student(
  uuid, uuid, text, smallint, text, text, text, text, timestamptz
) to authenticated;

commit;
