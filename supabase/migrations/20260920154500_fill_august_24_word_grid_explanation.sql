-- 補上 2026-08-24 已發布題目的當期解答說明。

update public.word_grid_puzzles
set answer_explanation = E'1. 修昔底德陷阱／新興強權崛起並挑戰既有強權時，雙方容易陷入衝突的國際關係概念。\n2. 斯巴達／古希臘城邦。\n3. 印度恆河／印度教聖河。\n4. 目暮警官／《名偵探柯南》中的警察角色。\n5. 底格里斯河／中東地區著名河流。',
    updated_at = now()
where published_on = date '2026-08-24';
