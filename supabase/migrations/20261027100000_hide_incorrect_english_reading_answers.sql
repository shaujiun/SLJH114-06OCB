-- 學生答錯時只回傳判定結果，不將正解、解析或教師設定的原文依據送到瀏覽器。
create or replace function public.submit_english_reading_answer(
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

  if not correct then
    return jsonb_build_object('correct', false);
  end if;
  return jsonb_build_object('correct', true, 'expected', key_row.answers,
    'explanation', key_row.explanation, 'evidenceSentence', key_row.evidence_sentence);
end;
$$;

revoke all on function public.submit_english_reading_answer(uuid, text[], text) from public, anon;
grant execute on function public.submit_english_reading_answer(uuid, text[], text) to authenticated;
