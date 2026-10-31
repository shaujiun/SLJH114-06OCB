-- 依使用者提供的報紙照片，補上已確認發布期數的當期解答說明。

update public.word_grid_puzzles
set answer_explanation = E'1. 六堆／清代臺灣南部客家聚落的民兵組織與地域稱呼。\n2. 海上生明月／張九齡〈望月懷遠〉詩句。\n3. 花旗木／花期可持續數月的觀賞花木。\n4. 明月出天山／李白〈關山月〉詩句。\n5. 清時有味是無能／杜牧〈將赴吳興登樂遊原一絕〉詩句。\n6. 回舟不待月／李白〈子夜吳歌．夏歌〉詩句。\n7. 六月雪／臺灣原生植物。\n8. 接殺／球被防守球員在落地前接住，使打者出局的棒球術語。',
    updated_at = now()
where published_on = date '2026-08-10';

update public.word_grid_puzzles
set answer_explanation = E'1. 豈向人間住／劉長卿〈送上人〉詩句。\n2. 惠妮休斯頓／美國歌手、演員。\n3. 學妹／鄭馥儀歌曲。\n4. 張惠妹／臺灣歌手。\n5. 安地斯山脈／位於南美洲西部的山脈。',
    updated_at = now()
where published_on = date '2026-08-31';

update public.word_grid_puzzles
set answer_explanation = E'1. 太阿倒持／比喻權柄落入他人手中，自己反受其害。\n2. 戰鬥陀螺／曾廣受孩童歡迎的玩具。\n3. 異人／子楚，後來的秦莊襄王。\n4. 車載斗量／形容數量很多，不足為奇。\n5. 持修／臺灣創作歌手。\n6. 白無常／民間宗教信仰神祇，常稱「七爺謝必安」。\n7. 台北人／白先勇小說集。',
    updated_at = now()
where published_on = date '2026-09-14';
