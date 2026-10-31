-- 題目可公開給開放中的學生；答案只由管理者讀取，學生送出後由函式判分。
create table public.english_reading_questions (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.english_reading_lessons(id) on delete cascade,
  position integer not null default 1 check (position > 0),
  kind text not null check (kind in ('choice', 'cloze')),
  group_scope text not null default 'all' check (group_scope in ('all', 'A', 'B')),
  prompt text not null check (length(trim(prompt)) > 0),
  options text[] not null default '{}',
  blank_count integer not null default 1 check (blank_count between 1 and 6),
  hint_a text not null default '',
  hint_b text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint english_reading_question_shape check (
    (kind = 'choice' and cardinality(options) between 2 and 4 and blank_count = 1)
    or (kind = 'cloze' and cardinality(options) = 0)
  )
);
create index english_reading_questions_lesson_order_idx on public.english_reading_questions(lesson_id, position);

create table public.english_reading_answer_keys (
  question_id uuid primary key references public.english_reading_questions(id) on delete cascade,
  answers text[] not null check (cardinality(answers) between 1 and 6),
  explanation text not null default '',
  evidence_sentence text not null default ''
);

create table public.english_reading_attempts (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.english_reading_questions(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  submitted_answers text[] not null,
  selected_evidence text not null default '',
  is_correct boolean not null,
  created_at timestamptz not null default now()
);
create index english_reading_attempts_student_idx on public.english_reading_attempts(student_id, created_at desc);

alter table public.english_reading_questions enable row level security;
alter table public.english_reading_answer_keys enable row level security;
alter table public.english_reading_attempts enable row level security;

create policy english_reading_questions_admin on public.english_reading_questions
  for all to authenticated using (public.can_manage_english_reading())
  with check (public.can_manage_english_reading());
create policy english_reading_questions_student on public.english_reading_questions
  for select to authenticated using (
    public.is_active_learning_student()
    and exists (
      select 1 from public.english_reading_lessons lesson
      where lesson.id = lesson_id
        and lesson.status = 'published'
        and lesson.available_from <= (now() at time zone 'Asia/Taipei')::date
        and lesson.available_until >= (now() at time zone 'Asia/Taipei')::date
    )
    and (
      group_scope = 'all' or group_scope = public.resolve_student_learning_group(
        (select student.id from public.students student where student.profile_id = auth.uid() and student.is_active limit 1),
        'english', (now() at time zone 'Asia/Taipei')::date
      )
    )
  );
create policy english_reading_keys_admin on public.english_reading_answer_keys
  for all to authenticated using (public.can_manage_english_reading())
  with check (public.can_manage_english_reading());
create policy english_reading_attempts_admin on public.english_reading_attempts
  for select to authenticated using (public.can_manage_english_reading());
create policy english_reading_attempts_student on public.english_reading_attempts
  for select to authenticated using (
    public.is_active_learning_student() and exists (
      select 1 from public.students student where student.id = student_id and student.profile_id = auth.uid()
    )
  );

revoke all on public.english_reading_questions, public.english_reading_answer_keys,
  public.english_reading_attempts from public, anon;
grant select on public.english_reading_questions to authenticated;
grant select on public.english_reading_answer_keys to authenticated;
grant select on public.english_reading_attempts to authenticated;

-- 保存題目及私有答案必須是一個交易，避免只有題目沒有正解。
create function public.save_english_reading_question(
  p_lesson_id uuid, p_question_id uuid, p_position integer, p_kind text,
  p_group_scope text, p_prompt text, p_options text[], p_answers text[],
  p_explanation text, p_evidence_sentence text, p_hint_a text, p_hint_b text
) returns uuid
language plpgsql security definer set search_path = public
as $$
declare saved_id uuid;
begin
  if not public.can_manage_english_reading() then raise exception 'admin_required'; end if;
  if not exists (select 1 from public.english_reading_lessons where id = p_lesson_id) then
    raise exception 'lesson_not_found';
  end if;
  if p_kind not in ('choice', 'cloze') or p_group_scope not in ('all', 'A', 'B')
    or length(trim(coalesce(p_prompt, ''))) = 0 or p_position < 1 then
    raise exception 'invalid_question';
  end if;
  if p_answers is null or p_kind = 'choice' and (p_options is null
      or cardinality(p_options) not between 2 and 4
      or cardinality(p_answers) <> 1
      or upper(trim(p_answers[1])) not in ('A', 'B', 'C', 'D')
      or ascii(upper(trim(p_answers[1]))) - ascii('A') + 1 > cardinality(p_options)) then
    raise exception 'invalid_choice_answer';
  end if;
  if p_kind = 'cloze' and (cardinality(coalesce(p_options, '{}'::text[])) <> 0
      or cardinality(p_answers) not between 1 and 6) then
    raise exception 'invalid_cloze_answer';
  end if;
  if exists (select 1 from unnest(p_answers) answer where length(trim(answer)) = 0) then
    raise exception 'empty_answer';
  end if;
  if p_kind = 'choice' and exists (select 1 from unnest(p_options) choice where length(trim(choice)) = 0) then
    raise exception 'empty_choice';
  end if;

  if p_question_id is null then
    insert into public.english_reading_questions
      (lesson_id, position, kind, group_scope, prompt, options, blank_count, hint_a, hint_b)
    values (p_lesson_id, p_position, p_kind, p_group_scope, trim(p_prompt),
      case when p_kind = 'choice' then p_options else '{}'::text[] end,
      case when p_kind = 'choice' then 1 else cardinality(p_answers) end,
      coalesce(p_hint_a, ''), coalesce(p_hint_b, '')) returning id into saved_id;
  else
    update public.english_reading_questions set
      position = p_position, kind = p_kind, group_scope = p_group_scope,
      prompt = trim(p_prompt),
      options = case when p_kind = 'choice' then p_options else '{}'::text[] end,
      blank_count = case when p_kind = 'choice' then 1 else cardinality(p_answers) end,
      hint_a = coalesce(p_hint_a, ''), hint_b = coalesce(p_hint_b, ''), updated_at = now()
    where id = p_question_id and lesson_id = p_lesson_id returning id into saved_id;
    if saved_id is null then raise exception 'question_not_found'; end if;
  end if;
  insert into public.english_reading_answer_keys(question_id, answers, explanation, evidence_sentence)
  values (saved_id, p_answers, coalesce(p_explanation, ''), coalesce(p_evidence_sentence, ''))
  on conflict (question_id) do update set answers = excluded.answers,
    explanation = excluded.explanation, evidence_sentence = excluded.evidence_sentence;
  return saved_id;
end;
$$;

create function public.submit_english_reading_answer(
  p_question_id uuid, p_answers text[], p_evidence_text text default ''
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare current_student_id uuid; item record; key_row record; current_group text;
  expected_count integer; correct boolean := true; answer_index integer; normalized text;
begin
  if not public.is_active_learning_student() then raise exception 'student_required'; end if;
  select id into current_student_id from public.students
    where profile_id = auth.uid() and is_active limit 1;
  select question.*, lesson.status, lesson.available_from, lesson.available_until
    into item from public.english_reading_questions question
    join public.english_reading_lessons lesson on lesson.id = question.lesson_id
    where question.id = p_question_id;
  if not found then raise exception 'question_unavailable'; end if;
  if item.status <> 'published'
    or (now() at time zone 'Asia/Taipei')::date not between item.available_from and item.available_until then
    raise exception 'question_unavailable';
  end if;
  current_group := public.resolve_student_learning_group(
    current_student_id, 'english', (now() at time zone 'Asia/Taipei')::date);
  if item.group_scope <> 'all' and item.group_scope <> current_group then
    raise exception 'question_unavailable';
  end if;
  select * into key_row from public.english_reading_answer_keys where question_id = p_question_id;
  expected_count := case when item.kind = 'choice' then 1 else item.blank_count end;
  if key_row.question_id is null or p_answers is null or cardinality(p_answers) <> expected_count then
    raise exception 'invalid_submission';
  end if;
  for answer_index in 1..expected_count loop
    normalized := lower(trim(p_answers[answer_index]));
    if normalized = '' or not exists (
      select 1 from unnest(string_to_array(key_row.answers[answer_index], '|')) accepted
      where lower(trim(accepted)) = normalized
    ) then correct := false; end if;
  end loop;
  insert into public.english_reading_attempts
    (question_id, student_id, submitted_answers, selected_evidence, is_correct)
  values (p_question_id, current_student_id, p_answers, left(coalesce(p_evidence_text, ''), 1000), correct);
  return jsonb_build_object('correct', correct, 'expected', key_row.answers,
    'explanation', key_row.explanation, 'evidenceSentence', key_row.evidence_sentence);
end;
$$;

create function public.delete_english_reading_question(p_question_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
declare target_lesson uuid; lesson_status text;
begin
  if not public.can_manage_english_reading() then raise exception 'admin_required'; end if;
  select question.lesson_id, lesson.status into target_lesson, lesson_status
  from public.english_reading_questions question
  join public.english_reading_lessons lesson on lesson.id = question.lesson_id
  where question.id = p_question_id
  for update of lesson;
  if target_lesson is null then raise exception 'question_not_found'; end if;
  if lesson_status = 'published' and (
    select count(*) from public.english_reading_questions where lesson_id = target_lesson
  ) <= 1 then raise exception 'last_published_question'; end if;
  delete from public.english_reading_questions where id = p_question_id;
end;
$$;

revoke all on function public.save_english_reading_question(uuid, uuid, integer, text, text, text, text[], text[], text, text, text, text) from public, anon;
revoke all on function public.submit_english_reading_answer(uuid, text[], text) from public, anon;
revoke all on function public.delete_english_reading_question(uuid) from public, anon;
grant execute on function public.save_english_reading_question(uuid, uuid, integer, text, text, text, text[], text[], text, text, text, text) to authenticated;
grant execute on function public.submit_english_reading_answer(uuid, text[], text) to authenticated;
grant execute on function public.delete_english_reading_question(uuid) to authenticated;

-- 只有具備可判分題目的文章才能發布，避免學生進入後只看到 OCR 草稿。
create function public.require_english_reading_questions_before_publish()
returns trigger language plpgsql set search_path = public
as $$
begin
  if new.status = 'published' and not exists (
    select 1 from public.english_reading_questions question
    join public.english_reading_answer_keys answer_key on answer_key.question_id = question.id
    where question.lesson_id = new.id
  ) then
    raise exception 'reading_questions_required_before_publish';
  end if;
  return new;
end;
$$;
create trigger english_reading_require_questions
  before insert or update of status on public.english_reading_lessons
  for each row execute function public.require_english_reading_questions_before_publish();
