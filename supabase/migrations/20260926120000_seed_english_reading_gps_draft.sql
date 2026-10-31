-- 2026-09-21 好讀周報英語閱讀草稿。
-- 依教師提供的同頁照片人工校對建立；保持 draft，待教師再次核對後才可發布。

insert into public.english_reading_lessons (
  id, issue_on, title, author_name, source_name,
  english_text, translation_text, grammar_text, core_words, extra_words,
  mind_map_text, cloze_text, questions_text, group_a_hint, group_b_hint,
  usage_note, status
)
select
  '82f12a6f-3c19-4d21-8d7b-202609210001'::uuid,
  '2026-09-21'::date,
  'A Stormy Day for GPS',
  'Coach Jeff',
  '聯合報好讀周報',
  $english$The Sun does more than light up our sky. Sometimes it can cause serious trouble for our technology. For example, millions of people depend on GPS to find their way, and so do automatic farming tractors and self-driving cars. However, in November 2025, a powerful solar storm hit the Earth and disturbed these important signals by releasing a huge burst of energy into space.

When that burst reached Earth, it confused the signals between satellites and the ground. Scientists found that GPS locations were suddenly wrong by nearly 10 meters. That may not sound like a lot, but it is enough to send a self-driving car into the wrong lane on a road or cause a tractor to damage crops. Luckily, this solar storm happened after the farming season had ended. Scientists are thinking about how to stop solar storms from causing problems in the future.$english$,
  $translation$太陽的作用不只是照亮我們的天空。有時候，它也會為我們的科技帶來嚴重的麻煩。舉例來說，數百萬人依賴 GPS 尋找方向，自動農耕拖拉機和自駕車也是如此。然而，2025 年 11 月，一場強大的太陽風暴襲擊地球，向太空釋放巨大的能量，干擾了這些重要的訊號。

當那股爆發的能量抵達地球時，它干擾了衛星與地面之間的訊號。科學家發現，GPS 定位突然出現將近 10 公尺的誤差。這聽起來或許不算多，但已足以讓自駕車駛入錯誤的車道，或讓拖拉機損壞農作物。幸運的是，這場太陽風暴發生在農耕季節結束之後。科學家們正在思考，未來要如何防止太陽風暴造成問題。$translation$,
  '可以用「stop + 名詞／受詞 + from + V-ing」表達「阻止某人或某事發生」。stop 要依句子的時態變化；from 後面的動詞要改成 V-ing。',
  $words$serious 嚴重的
depend 依賴
burst 爆發
sudden 突然的
damage 損害
happen 發生$words$,
  $words$technology 科技
satellite 衛星$words$,
  $map$technology → depend on GPS → satellite signals
solar storm → burst of energy → confused signals → GPS error
GPS error → wrong lane／damage crops → serious problem$map$,
  $cloze$Word Box：cry／fall／kick／point／win／see

1. I always ____ my baby sister from ____ by making funny faces to make her laugh instead.
2. No one can ____ us from ____ the soccer match! We have all of the best players on our team.
3. During yesterday's earthquake, Janet ____ herself from ____ by gripping the big table.$cloze$,
  $questions$1. What is the main idea of the article?
A. Solar storms are becoming more powerful and more dangerous every year.
B. A solar storm in 2025 confused a lot of technology.
C. Scientists are trying to protect the Sun from being damaged by GPS systems.

2. Why is a 10-meter GPS error dangerous for a self-driving car?
A. It is enough to send the car into the wrong lane.
B. A 10-meter error means the car cannot find the road at all.
C. It can cause self-driving cars to damage crops.

3. What does the article say scientists are doing about the problem?
A. They are building new satellites that are stronger than solar storms.
B. They are warning farmers and drivers when solar storms are coming.
C. They are thinking about how to stop solar storms from causing problems.$questions$,
  '先圈出題目中的關鍵字，再回到原文找同義敘述；選答案前說出另外兩個選項錯在哪裡。',
  '先從題目找關鍵字，再對照原文中含有 GPS、10 meters 或 Scientists 的句子。填空題先找 stop 的時態，再把 from 後面的動詞改成 V-ing。',
  '聯合報好讀周報課堂閱讀練習；限已核准學生帳號於教師發布期間內使用。發布前仍須由教師逐字校對。',
  'draft'
where not exists (
  select 1 from public.english_reading_lessons
  where issue_on = '2026-09-21'::date and title = 'A Stormy Day for GPS'
)
on conflict (id) do nothing;

insert into public.english_reading_questions (
  id, lesson_id, position, kind, group_scope, prompt, options, blank_count, hint_a, hint_b
)
select question.id, question.lesson_id, question.position, question.kind, question.group_scope,
  question.prompt, question.options, question.blank_count, question.hint_a, question.hint_b
from (values
  (
    '82f12a6f-3c19-4d21-8d7b-202609210101'::uuid,
    '82f12a6f-3c19-4d21-8d7b-202609210001'::uuid,
    1, 'cloze', 'all',
    'I always ____ my baby sister from ____ by making funny faces to make her laugh instead.',
    '{}'::text[], 2,
    '注意 always 所搭配的時態，以及 from 後面的動詞形式。',
    'Word Box 可用 cry；句型是 stop + 人 + from + V-ing。'
  ),
  (
    '82f12a6f-3c19-4d21-8d7b-202609210102'::uuid,
    '82f12a6f-3c19-4d21-8d7b-202609210001'::uuid,
    2, 'cloze', 'all',
    'No one can ____ us from ____ the soccer match! We have all of the best players on our team.',
    '{}'::text[], 2,
    'can 後面使用原形動詞；判斷球賽語意需要 Word Box 中哪個字。',
    '第一格是 stop；第二格從 win 變成 V-ing。'
  ),
  (
    '82f12a6f-3c19-4d21-8d7b-202609210103'::uuid,
    '82f12a6f-3c19-4d21-8d7b-202609210001'::uuid,
    3, 'cloze', 'all',
    'During yesterday''s earthquake, Janet ____ herself from ____ by gripping the big table.',
    '{}'::text[], 2,
    'yesterday 提示第一格要使用過去式；第二格描述抓住桌子避免發生的事。',
    'stop 要改為過去式 stopped；fall 要改成 V-ing。'
  ),
  (
    '82f12a6f-3c19-4d21-8d7b-202609210104'::uuid,
    '82f12a6f-3c19-4d21-8d7b-202609210001'::uuid,
    4, 'choice', 'all',
    'What is the main idea of the article?',
    array[
      'Solar storms are becoming more powerful and more dangerous every year.',
      'A solar storm in 2025 confused a lot of technology.',
      'Scientists are trying to protect the Sun from being damaged by GPS systems.'
    ]::text[], 1,
    '主旨要能涵蓋兩段內容，不要只看單一句子。',
    '文章描述太陽風暴如何干擾 GPS，以及造成的問題。'
  ),
  (
    '82f12a6f-3c19-4d21-8d7b-202609210105'::uuid,
    '82f12a6f-3c19-4d21-8d7b-202609210001'::uuid,
    5, 'choice', 'all',
    'Why is a 10-meter GPS error dangerous for a self-driving car?',
    array[
      'It is enough to send the car into the wrong lane.',
      'A 10-meter error means the car cannot find the road at all.',
      'It can cause self-driving cars to damage crops.'
    ]::text[], 1,
    '回到原文找 10 meters 後面的 but 轉折句。',
    '找含有 10 meters、self-driving car 和 wrong lane 的句子。'
  ),
  (
    '82f12a6f-3c19-4d21-8d7b-202609210106'::uuid,
    '82f12a6f-3c19-4d21-8d7b-202609210001'::uuid,
    6, 'choice', 'all',
    'What does the article say scientists are doing about the problem?',
    array[
      'They are building new satellites that are stronger than solar storms.',
      'They are warning farmers and drivers when solar storms are coming.',
      'They are thinking about how to stop solar storms from causing problems.'
    ]::text[], 1,
    '答案在文章最後一句；注意題目問的是 scientists are doing。',
    '直接對照最後一句 Scientists are thinking about how to stop...。'
  )
) as question(id, lesson_id, position, kind, group_scope, prompt, options, blank_count, hint_a, hint_b)
where exists (select 1 from public.english_reading_lessons lesson where lesson.id = question.lesson_id)
on conflict (id) do nothing;

insert into public.english_reading_answer_keys (question_id, answers, explanation, evidence_sentence)
values
  (
    '82f12a6f-3c19-4d21-8d7b-202609210101'::uuid,
    array['stop', 'crying']::text[],
    'always 表示習慣，使用 stop；from 後面的 cry 要改為 crying。',
    '句型：stop + 人／事 + from + V-ing。'
  ),
  (
    '82f12a6f-3c19-4d21-8d7b-202609210102'::uuid,
    array['stop', 'winning']::text[],
    '情態動詞 can 後用 stop 原形；from 後面的 win 要雙寫 n 再加 -ing。',
    '句型：stop + 人／事 + from + V-ing。'
  ),
  (
    '82f12a6f-3c19-4d21-8d7b-202609210103'::uuid,
    array['stopped', 'falling']::text[],
    'yesterday 表示過去，stop 要改成 stopped；fall 加 -ing 成為 falling。',
    '句型：stop + 人／事 + from + V-ing。'
  ),
  (
    '82f12a6f-3c19-4d21-8d7b-202609210104'::uuid,
    array['B']::text[],
    '兩段都圍繞 2025 年的太陽風暴干擾 GPS 訊號及其影響；A 與 C 都不是文章主旨。',
    'However, in November 2025, a powerful solar storm hit the Earth and disturbed these important signals by releasing a huge burst of energy into space.'
  ),
  (
    '82f12a6f-3c19-4d21-8d7b-202609210105'::uuid,
    array['A']::text[],
    '10 公尺的定位誤差已足以讓自駕車進入錯誤車道。農作物受損是拖拉機的例子。',
    'That may not sound like a lot, but it is enough to send a self-driving car into the wrong lane on a road or cause a tractor to damage crops.'
  ),
  (
    '82f12a6f-3c19-4d21-8d7b-202609210106'::uuid,
    array['C']::text[],
    '文章最後說科學家正思考如何阻止太陽風暴在未來造成問題。',
    'Scientists are thinking about how to stop solar storms from causing problems in the future.'
  )
on conflict (question_id) do nothing;
