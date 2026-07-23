-- Personal grade history, secure workbook imports, publishing, and student self-read access.

begin;

create table if not exists public.grade_exam_periods (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  exam_key text not null check (exam_key ~ '^(g[789]-s[123]-e[12]|mock-[1-4])$'),
  display_name text not null check (length(trim(display_name)) between 2 and 30),
  exam_type text not null check (exam_type in ('term', 'mock')),
  school_year integer not null check (school_year between 100 and 999),
  grade_level integer not null check (grade_level between 7 and 9),
  semester integer check (semester between 1 and 3),
  exam_number integer not null check (exam_number between 1 and 4),
  sort_order integer not null check (sort_order between 1 and 999),
  is_published boolean not null default false,
  published_at timestamptz,
  created_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint grade_exam_period_class_key_unique unique (class_id, exam_key),
  constraint grade_exam_period_type_fields_check check (
    (exam_type = 'term' and semester is not null and exam_number between 1 and 2)
    or (exam_type = 'mock' and semester is null and exam_number between 1 and 4)
  ),
  constraint grade_exam_period_publish_time_check check (
    (is_published and published_at is not null)
    or (not is_published and published_at is null)
  )
);

create index if not exists grade_exam_periods_class_sort_idx
  on public.grade_exam_periods(class_id, sort_order);

create table if not exists public.grade_import_batches (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  source_file_name text not null check (length(trim(source_file_name)) between 1 and 255),
  exam_count integer not null check (exam_count between 1 and 22),
  result_count integer not null check (result_count between 1 and 1000),
  imported_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  imported_at timestamptz not null default now()
);

create index if not exists grade_import_batches_class_time_idx
  on public.grade_import_batches(class_id, imported_at desc);

create table if not exists public.student_grade_results (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.grade_exam_periods(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  import_batch_id uuid not null references public.grade_import_batches(id) on delete restrict,
  snapshot_student_id_code citext not null,
  snapshot_seat_number integer not null check (snapshot_seat_number > 0),
  snapshot_full_name text not null,
  snapshot_class_label text not null,
  chinese_score numeric(6, 2),
  composition_score numeric(6, 2),
  english_written_score numeric(6, 2),
  english_listening_score numeric(6, 2),
  english_score numeric(6, 2),
  math_score numeric(6, 2),
  science_score numeric(6, 2),
  history_score numeric(6, 2),
  geography_score numeric(6, 2),
  civics_score numeric(6, 2),
  total_score numeric(8, 2),
  weighted_total_score numeric(10, 2),
  class_rank integer,
  school_rank integer,
  source_sheet text,
  source_row integer,
  recorded_by uuid not null references public.contact_book_profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint student_grade_result_exam_student_unique unique (exam_id, student_id),
  constraint student_grade_result_scores_check check (
    (chinese_score is null or chinese_score between 0 and 100)
    and (composition_score is null or composition_score between 0 and 100)
    and (english_written_score is null or english_written_score between 0 and 100)
    and (english_listening_score is null or english_listening_score between 0 and 100)
    and (english_score is null or english_score between 0 and 100)
    and (math_score is null or math_score between 0 and 100)
    and (science_score is null or science_score between 0 and 100)
    and (history_score is null or history_score between 0 and 100)
    and (geography_score is null or geography_score between 0 and 100)
    and (civics_score is null or civics_score between 0 and 100)
    and (total_score is null or total_score between 0 and 700)
    and (weighted_total_score is null or weighted_total_score between 0 and 10000)
    and (class_rank is null or class_rank > 0)
    and (school_rank is null or school_rank > 0)
  )
);

create index if not exists student_grade_results_student_exam_idx
  on public.student_grade_results(student_id, exam_id);
create index if not exists student_grade_results_exam_seat_idx
  on public.student_grade_results(exam_id, snapshot_seat_number);

drop trigger if exists grade_exam_periods_set_updated_at on public.grade_exam_periods;
create trigger grade_exam_periods_set_updated_at
before update on public.grade_exam_periods
for each row execute function public.contact_book_set_updated_at();

drop trigger if exists student_grade_results_set_updated_at on public.student_grade_results;
create trigger student_grade_results_set_updated_at
before update on public.student_grade_results
for each row execute function public.contact_book_set_updated_at();

alter table public.grade_exam_periods enable row level security;
alter table public.grade_import_batches enable row level security;
alter table public.student_grade_results enable row level security;

drop policy if exists grade_exam_periods_read_allowed on public.grade_exam_periods;
create policy grade_exam_periods_read_allowed on public.grade_exam_periods
for select to authenticated using (
  public.can_manage_class(class_id)
  or (is_published and public.can_view_class(class_id))
);

drop policy if exists grade_import_batches_admin_read on public.grade_import_batches;
create policy grade_import_batches_admin_read on public.grade_import_batches
for select to authenticated using (public.can_manage_class(class_id));

drop policy if exists student_grade_results_read_allowed on public.student_grade_results;
create policy student_grade_results_read_allowed on public.student_grade_results
for select to authenticated using (
  public.can_manage_class(class_id)
  or (
    public.is_student_self(student_id)
    and exists (
      select 1
      from public.grade_exam_periods exam
      where exam.id = exam_id and exam.is_published
    )
  )
);

create or replace function public.admin_import_grade_workbook(
  p_class_id uuid,
  p_source_file_name text,
  p_exams jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_class public.classes%rowtype;
  batch_id uuid;
  exam_item jsonb;
  target_exam_id uuid;
  target_exam_key text;
  target_display_name text;
  target_exam_type text;
  target_school_year integer;
  target_grade_level integer;
  target_semester integer;
  target_exam_number integer;
  target_sort_order integer;
  target_rows jsonb;
  requested_exam_count integer;
  requested_result_count integer := 0;
  affected_count integer := 0;
  current_count integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select class_row.* into target_class
  from public.classes class_row
  where class_row.id = p_class_id and class_row.is_active;
  if not found or not public.can_manage_class(p_class_id) then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if length(trim(coalesce(p_source_file_name, ''))) not between 1 and 255
    or jsonb_typeof(coalesce(p_exams, 'null'::jsonb)) <> 'array' then
    raise exception 'invalid_grade_import';
  end if;

  requested_exam_count := jsonb_array_length(p_exams);
  if requested_exam_count not between 1 and 22 then raise exception 'invalid_grade_import'; end if;

  for exam_item in select value from jsonb_array_elements(p_exams)
  loop
    target_exam_key := trim(exam_item->>'exam_key');
    target_display_name := trim(exam_item->>'display_name');
    target_exam_type := exam_item->>'exam_type';
    target_school_year := (exam_item->>'school_year')::integer;
    target_grade_level := (exam_item->>'grade_level')::integer;
    target_semester := nullif(exam_item->>'semester', '')::integer;
    target_exam_number := (exam_item->>'exam_number')::integer;
    target_sort_order := (exam_item->>'sort_order')::integer;
    target_rows := exam_item->'rows';

    if target_exam_key !~ '^(g[789]-s[123]-e[12]|mock-[1-4])$'
      or length(target_display_name) not between 2 and 30
      or target_exam_type not in ('term', 'mock')
      or target_school_year not between 100 and 999
      or target_grade_level not between 7 and 9
      or target_exam_number not between 1 and 4
      or target_sort_order not between 1 and 999
      or jsonb_typeof(coalesce(target_rows, 'null'::jsonb)) <> 'array'
      or jsonb_array_length(target_rows) not between 1 and 100
      or (target_exam_type = 'term' and (target_semester not between 1 and 3 or target_exam_number not between 1 and 2))
      or (target_exam_type = 'mock' and target_semester is not null) then
      raise exception 'invalid_grade_import';
    end if;

    if exists (
      select 1
      from jsonb_to_recordset(target_rows) as row_data(student_id uuid)
      left join public.students student
        on student.id = row_data.student_id and student.class_id = p_class_id and student.is_active
      where student.id is null
    ) then raise exception 'invalid_student'; end if;

    if (
      select count(*) <> count(distinct row_data.student_id)
      from jsonb_to_recordset(target_rows) as row_data(student_id uuid)
    ) or exists (
      select 1
      from jsonb_to_recordset(target_rows) as row_data(
        student_id uuid,
        chinese_score numeric,
        composition_score numeric,
        english_written_score numeric,
        english_listening_score numeric,
        english_score numeric,
        math_score numeric,
        science_score numeric,
        history_score numeric,
        geography_score numeric,
        civics_score numeric,
        total_score numeric,
        weighted_total_score numeric,
        class_rank integer,
        school_rank integer,
        source_row integer
      )
      where (chinese_score is not null and chinese_score not between 0 and 100)
        or (composition_score is not null and composition_score not between 0 and 100)
        or (english_written_score is not null and english_written_score not between 0 and 100)
        or (english_listening_score is not null and english_listening_score not between 0 and 100)
        or (english_score is not null and english_score not between 0 and 100)
        or (math_score is not null and math_score not between 0 and 100)
        or (science_score is not null and science_score not between 0 and 100)
        or (history_score is not null and history_score not between 0 and 100)
        or (geography_score is not null and geography_score not between 0 and 100)
        or (civics_score is not null and civics_score not between 0 and 100)
        or (total_score is not null and total_score not between 0 and 700)
        or (weighted_total_score is not null and weighted_total_score not between 0 and 10000)
        or (class_rank is not null and class_rank < 1)
        or (school_rank is not null and school_rank < 1)
        or (source_row is not null and source_row < 1)
    ) then raise exception 'invalid_grade_import'; end if;

    insert into public.grade_exam_periods (
      class_id, exam_key, display_name, exam_type, school_year, grade_level,
      semester, exam_number, sort_order, created_by
    ) values (
      p_class_id, target_exam_key, target_display_name, target_exam_type, target_school_year,
      target_grade_level, target_semester, target_exam_number, target_sort_order, auth.uid()
    )
    on conflict (class_id, exam_key) do update
    set display_name = excluded.display_name,
        exam_type = excluded.exam_type,
        school_year = excluded.school_year,
        grade_level = excluded.grade_level,
        semester = excluded.semester,
        exam_number = excluded.exam_number,
        sort_order = excluded.sort_order,
        updated_at = now()
    returning id into target_exam_id;

    requested_result_count := requested_result_count + jsonb_array_length(target_rows);

    if batch_id is null then
      insert into public.grade_import_batches (
        class_id, source_file_name, exam_count, result_count, imported_by
      ) values (
        p_class_id, trim(p_source_file_name), requested_exam_count, 1, auth.uid()
      ) returning id into batch_id;
    end if;

    insert into public.student_grade_results (
      exam_id, class_id, student_id, import_batch_id,
      snapshot_student_id_code, snapshot_seat_number, snapshot_full_name, snapshot_class_label,
      chinese_score, composition_score, english_written_score, english_listening_score,
      english_score, math_score, science_score, history_score, geography_score, civics_score,
      total_score, weighted_total_score, class_rank, school_rank,
      source_sheet, source_row, recorded_by
    )
    select
      target_exam_id, p_class_id, student.id, batch_id,
      student.student_id_code, student.seat_number, student.full_name,
      concat(target_grade_level, lpad(target_class.class_number::text, 2, '0')),
      row_data.chinese_score, row_data.composition_score,
      row_data.english_written_score, row_data.english_listening_score,
      row_data.english_score, row_data.math_score, row_data.science_score,
      row_data.history_score, row_data.geography_score, row_data.civics_score,
      row_data.total_score, row_data.weighted_total_score,
      row_data.class_rank, row_data.school_rank,
      nullif(trim(row_data.source_sheet), ''), row_data.source_row, auth.uid()
    from jsonb_to_recordset(target_rows) as row_data(
      student_id uuid,
      chinese_score numeric,
      composition_score numeric,
      english_written_score numeric,
      english_listening_score numeric,
      english_score numeric,
      math_score numeric,
      science_score numeric,
      history_score numeric,
      geography_score numeric,
      civics_score numeric,
      total_score numeric,
      weighted_total_score numeric,
      class_rank integer,
      school_rank integer,
      source_sheet text,
      source_row integer
    )
    join public.students student on student.id = row_data.student_id
    on conflict (exam_id, student_id) do update
    set import_batch_id = excluded.import_batch_id,
        snapshot_student_id_code = excluded.snapshot_student_id_code,
        snapshot_seat_number = excluded.snapshot_seat_number,
        snapshot_full_name = excluded.snapshot_full_name,
        snapshot_class_label = excluded.snapshot_class_label,
        chinese_score = coalesce(excluded.chinese_score, student_grade_results.chinese_score),
        composition_score = coalesce(excluded.composition_score, student_grade_results.composition_score),
        english_written_score = coalesce(excluded.english_written_score, student_grade_results.english_written_score),
        english_listening_score = coalesce(excluded.english_listening_score, student_grade_results.english_listening_score),
        english_score = coalesce(excluded.english_score, student_grade_results.english_score),
        math_score = coalesce(excluded.math_score, student_grade_results.math_score),
        science_score = coalesce(excluded.science_score, student_grade_results.science_score),
        history_score = coalesce(excluded.history_score, student_grade_results.history_score),
        geography_score = coalesce(excluded.geography_score, student_grade_results.geography_score),
        civics_score = coalesce(excluded.civics_score, student_grade_results.civics_score),
        total_score = coalesce(excluded.total_score, student_grade_results.total_score),
        weighted_total_score = coalesce(excluded.weighted_total_score, student_grade_results.weighted_total_score),
        class_rank = coalesce(excluded.class_rank, student_grade_results.class_rank),
        school_rank = coalesce(excluded.school_rank, student_grade_results.school_rank),
        source_sheet = coalesce(excluded.source_sheet, student_grade_results.source_sheet),
        source_row = coalesce(excluded.source_row, student_grade_results.source_row),
        recorded_by = auth.uid(),
        updated_at = now();
    get diagnostics current_count = row_count;
    affected_count := affected_count + current_count;
  end loop;

  update public.grade_import_batches
  set result_count = requested_result_count
  where id = batch_id;

  return jsonb_build_object(
    'importBatchId', batch_id,
    'examCount', requested_exam_count,
    'resultCount', affected_count
  );
exception
  when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'invalid_grade_import';
end;
$$;

create or replace function public.admin_set_grade_exam_published(
  p_exam_id uuid,
  p_published boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_exam public.grade_exam_periods%rowtype;
  result_count integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select exam.* into target_exam
  from public.grade_exam_periods exam
  where exam.id = p_exam_id
  for update;
  if not found then raise exception 'invalid_exam'; end if;
  if not public.can_manage_class(target_exam.class_id) then
    raise exception 'permission_denied' using errcode = '42501';
  end if;

  select count(*) into result_count
  from public.student_grade_results result
  where result.exam_id = p_exam_id;
  if p_published and result_count = 0 then raise exception 'empty_exam'; end if;

  update public.grade_exam_periods exam
  set is_published = p_published,
      published_at = case when p_published then coalesce(exam.published_at, now()) else null end,
      updated_at = now()
  where exam.id = p_exam_id;

  return jsonb_build_object(
    'examId', p_exam_id,
    'published', p_published,
    'resultCount', result_count
  );
end;
$$;

revoke all on function public.admin_import_grade_workbook(uuid, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.admin_import_grade_workbook(uuid, text, jsonb)
  to authenticated;

revoke all on function public.admin_set_grade_exam_published(uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.admin_set_grade_exam_published(uuid, boolean)
  to authenticated;

commit;
