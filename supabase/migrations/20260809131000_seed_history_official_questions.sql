-- 由 scripts/generate-history-official-questions.mjs 產生。
-- 僅建立基測與會考正式題目草稿；不包含 Knowledge Atlas 自編解析。

with seed_questions (
  question_code, event_code, question_type, prompt, options, media_urls, question_tables,
  answer, explanation, source_name, source_year, source_url, original_event_ids,
  mapping_confidence, mapping_note, display_order, status
) as (
  values
    (
      'ka-jh-set1-s002', 'h4c3-08', 'past',
      '有一本小說，內容描述戰爭時期的學校生活，當時首都由南京遷到重慶，敵人則在原首都另立政權。書中主角隨政府撤退到西南後方，最後響應政府的號召而投筆從戎。這部小說的創作背景應是下列何者？', '[{"key":"A","text":"民國 15～17 年間國民革命軍北伐"},{"key":"B","text":"民國 23～25 年間中共「長征」"},{"key":"C","text":"民國 26～34 年間對日抗戰"},{"key":"D","text":"民國 39～42 年間韓戰衝突"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第一次基測', '97 年',
      'https://knowledgeatlas.cc/history/', array['cn-warjapan-1937']::text[], 96,
      '原網站事件「中日戰爭全面爆發」自動對應。', 2, 'draft'
    ),
    (
      'ka-jh-set1-s004', 'h4c2-01', 'past',
      '「我們主張若要造一種活的文學，必須用白話來做文學的工具。我們也知道單有白話未必就能造出新文章，……新文學必須要有新思想做裡子。」這段敘述最可能是下列何人提出的看法？', '[{"key":"A","text":"曾國藩"},{"key":"B","text":"康有為"},{"key":"C","text":"孫中山"},{"key":"D","text":"胡適"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '第二次基測', '95 年',
      'https://knowledgeatlas.cc/history/', array['cn-newculture-1915']::text[], 99,
      '原網站事件「新文化運動」自動對應。', 4, 'draft'
    ),
    (
      'ka-jh-set1-s010', 'h4c2-03', 'past',
      '許多大型活動都會設計獨特的圖案和口號，一方面宣示主張，一方面加強印象，政治活動也是如此。下列何者是五四運動時的代表性口號？', '[{"key":"A","text":"外爭主權，內除國賊"},{"key":"B","text":"停止剿共，一致抗日"},{"key":"C","text":"推翻滿清，建立民國"},{"key":"D","text":"革命無罪，造反有理"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '北北基', '100 年',
      'https://knowledgeatlas.cc/history/', array['china-mayfourth-1919']::text[], 99,
      '原網站事件「五四運動」自動對應。', 10, 'draft'
    ),
    (
      'ka-jh-set1-s012', 'h3c1-02', 'past',
      '星雅參加班上「西周風雲」話劇演出，飾演一位住在城中的貴族，若話劇內容須合於史實，下列何者最可能是他在劇中的生活情況？', '[{"key":"A","text":"依照身份等級，受封土地和爵位"},{"key":"B","text":"乘坐馬車，到夜市採買日常用品"},{"key":"C","text":"主持科舉考試，掌握官員的任命權"},{"key":"D","text":"熟讀四書五經，輔佐君王治理國家"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第一次基測', '100 年',
      'https://knowledgeatlas.cc/history/', array['cn-feudal-1046']::text[], 99,
      '原網站事件「西周封建制度」自動對應。', 12, 'draft'
    ),
    (
      'ka-jh-set1-s015', 'h3c5-08', 'past',
      '清光緒年間，中國割讓臺灣，部分知識分子反對割讓，主張建立臺灣民主國，率眾抵抗外國勢力的入侵。此事件起因於下列哪一場戰爭的失敗？', '[{"key":"A","text":"鴉片戰爭"},{"key":"B","text":"清法戰爭"},{"key":"C","text":"甲午戰爭"},{"key":"D","text":"八國聯軍"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第二次基測', '94 年',
      'https://knowledgeatlas.cc/history/', array['cn-sinojapanese-1894', 'tw-republic-1895']::text[], 96,
      '原網站事件「甲午戰爭與馬關條約」自動對應。', 15, 'draft'
    ),
    (
      'ka-jh-set1-s017', 'h3c2-07', 'past',
      '唐代玄奘對佛教中國化的貢獻極大，最主要是因他有下列何種重要作為？', '[{"key":"A","text":"廣建佛寺"},{"key":"B","text":"首創佛教宗派"},{"key":"C","text":"有系統地翻譯佛經"},{"key":"D","text":"新闢西行取經的捷徑"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第一次基測', '93 年',
      'https://knowledgeatlas.cc/history/', array['cn-tang-cosmopolitan']::text[], 99,
      '原網站事件「唐代多元文化交流」自動對應。', 17, 'draft'
    ),
    (
      'ka-jh-set1-s029', 'h3c4-03', 'past',
      '「海盜」是指出沒海洋，憑藉暴力威脅等手段，搶劫過往船隻財物的歹徒。他們的存在對海運安全構成極大威脅，是國際間相當令人頭痛的問題。附圖是某雜誌報導 2004 年 1 月到 9 月海盜最常出沒的區域圖，其中「x」代表該區曾發生海盜攻擊事件的地點。歷史上，有一位人物航經此區域時剿平當時為亂的海盜，提高了國家的聲望，奠定日後華僑在此地區發展的基礎。這位人物應是下列哪一位？', '[{"key":"A","text":"張騫"},{"key":"B","text":"朱熹"},{"key":"C","text":"畢昇"},{"key":"D","text":"鄭和"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set1-image9.png"]'::jsonb, '[]'::jsonb,
      'D', '', '第一次基測', '96 年',
      'https://knowledgeatlas.cc/history/', array['cn-zhenghe-1405']::text[], 99,
      '原網站事件「鄭和下西洋」自動對應。', 29, 'draft'
    ),
    (
      'ka-jh-set1-s030', 'h3c2-03', 'past',
      '家雄在星期天參加一場演講會，演講的內容以張騫、玄奘、徐光啟等人的事蹟為主，引起熱烈的討論。由此推斷，這次演講的主題最可能是下列哪一項？', '[{"key":"A","text":"外來宗教的中國化"},{"key":"B","text":"科技發展與文明變遷"},{"key":"C","text":"中西交通與文化交流"},{"key":"D","text":"中國文學的時代精神"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第二次基測', '91 年',
      'https://knowledgeatlas.cc/history/', array['cn-elements-1607', 'cn-silkroad']::text[], 94,
      '原網站事件「張騫通西域與絲路交流」自動對應。', 30, 'draft'
    ),
    (
      'ka-jh-set1-s031', 'h4c3-06', 'past',
      '劉伯伯到四川九寨溝旅遊，途中看到一個石碑豎立於山坡上，上面記載所謂「二萬五千里長征」的歷史事件。此石碑所記載的事件，其歷史背景為何？', '[{"key":"A","text":"民國 15～17 年革命軍北伐"},{"key":"B","text":"民國 19～24 年國共內戰"},{"key":"C","text":"民國 26～34 年對日抗戰"},{"key":"D","text":"民國 55～65 年文化大革命"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第二次基測', '91 年',
      'https://knowledgeatlas.cc/history/', array['cn-longmarch-1934', 'china-civilwar-1946']::text[], 99,
      '依題幹與答案複核：題目直接詢問紅軍長征。', 31, 'draft'
    ),
    (
      'ka-jh-set1-s038', 'h4c2-01', 'past',
      '小琪在圖書館看到一張舊傳單，上面寫著：
推倒雕琢的、阿諛的貴族文學；
建設平易的、抒情的國民文學。
推倒陳腐的、鋪張的古典文學；
建設新鮮的、立誠的寫實文學。
推倒迂晦的、艱澀的山林文學；
建設明瞭的、通俗的社會文學。
這種文學改革的訴求，反映出近代哪一次革新運動的精神？', '[{"key":"A","text":"自強運動"},{"key":"B","text":"戊戌變法"},{"key":"C","text":"新文化運動"},{"key":"D","text":"文化大革命"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第二次基測', '91 年',
      'https://knowledgeatlas.cc/history/', array['cn-newculture-1915']::text[], 99,
      '原網站事件「新文化運動」自動對應。', 38, 'draft'
    ),
    (
      'ka-jh-set1-s040', 'h3c3-06', 'past',
      '阿拉罕一家人世居中國西域一帶，自蒙古人統一中國後，他因擅長理財而受到政府的器重，負責國家徵稅的工作。阿拉罕最有可能是當時哪一個階級的人？', '[{"key":"A","text":"蒙古人"},{"key":"B","text":"色目人"},{"key":"C","text":"漢人"},{"key":"D","text":"南人"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '91 年',
      'https://knowledgeatlas.cc/history/', array['cn-mongol-conquest']::text[], 92,
      '原網站事件「蒙古擴張與元朝統一」自動對應。', 40, 'draft'
    ),
    (
      'ka-jh-set1-s049', 'h4c6-02', 'past',
      '第二次世界大戰後，陸續發生韓戰、越戰等國際衝突，這些衝突發生的共同背景為何？', '[{"key":"A","text":"亞、歐對抗"},{"key":"B","text":"中日對抗"},{"key":"C","text":"美、蘇冷戰"},{"key":"D","text":"國際聯盟瓦解"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第一次基測', '98 年',
      'https://knowledgeatlas.cc/history/', array['west-wwii-1939', 'west-coldwar-1947', 'korea-war-1950']::text[], 99,
      '原網站事件「韓戰」自動對應。', 49, 'draft'
    ),
    (
      'ka-jh-set1-s054', 'h4c2-01', 'past',
      '附圖為歷史老師在黑板上所寫的重點，依內容推斷，下列何者最可能是她講述的主題？', '[{"key":"A","text":"立憲運動的本質"},{"key":"B","text":"戊戌變法的特色"},{"key":"C","text":"新文化運動的內涵"},{"key":"D","text":"文化大革命的目標"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set1-image11.png"]'::jsonb, '[]'::jsonb,
      'C', '', '基測', '101 年',
      'https://knowledgeatlas.cc/history/', array['cn-newculture-1915']::text[], 99,
      '原網站事件「新文化運動」自動對應。', 54, 'draft'
    ),
    (
      'ka-jh-set1-s060', 'h3c2-07', 'past',
      '丹廷寫一篇歷史報告，結語如下：
總而言之，這個朝代是中國最具世界主義色彩的朝代。政治上，皇帝因打敗強敵東突厥，曾被周邊民族尊為國際盟主；社會上，……；宗教上，因對自己的文化具有自信與安全感，對信仰自由給予保障，許多宗教傳入，是一段充滿光輝的時期。
文中「……」部分，最適合填入下列哪一段敘述？', '[{"key":"A","text":"朝廷宣揚漢人文化，積極推行各種改革措施，如斷北語、通婚姻"},{"key":"B","text":"朝廷對於各種族一視同仁，許多留學生與外國人前來學習、定居"},{"key":"C","text":"朝廷為了方便管理，將人民區分為四個不同階級，訂定各種規範"},{"key":"D","text":"朝廷有感於西方國家科技先進產業發達，禮聘外國人士來華指導"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '99 年',
      'https://knowledgeatlas.cc/history/', array['cn-tang-cosmopolitan']::text[], 99,
      '原網站事件「唐代多元文化交流」自動對應。', 60, 'draft'
    ),
    (
      'ka-jh-set1-s061', 'h3c2-06', 'past',
      '元大木回憶年輕時，從平城遷居洛陽，並配合政府的政策與漢人結婚，改變穿著，甚至改用漢姓。他應該是哪一個時代的人？', '[{"key":"A","text":"秦漢"},{"key":"B","text":"南北朝"},{"key":"C","text":"隋唐"},{"key":"D","text":"明清"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第二次基測', '90 年',
      'https://knowledgeatlas.cc/history/', array['cn-northern-wei-reform']::text[], 99,
      '原網站事件「北魏孝文帝改革」自動對應。', 61, 'draft'
    ),
    (
      'ka-jh-set1-s068', 'h3c6-01', 'past',
      '有篇介紹某位清末歷史人物的文章，其中有段敘述如附圖。根據資料判斷，這篇文章介紹的歷史人物是誰？', '[{"key":"A","text":"李鴻章"},{"key":"B","text":"曾國藩"},{"key":"C","text":"康有為"},{"key":"D","text":"林則徐"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set1-image18.png"]'::jsonb, '[]'::jsonb,
      'C', '', '第一次基測', '93 年',
      'https://knowledgeatlas.cc/history/', array['cn-hundred-days-1898']::text[], 99,
      '原網站事件「戊戌變法」自動對應。', 68, 'draft'
    ),
    (
      'ka-jh-set1-s072', 'h3c4-03', 'past',
      '附表為某時期海外國家向中國入貢的次數統計表。由表中國家的分布區域判斷，他們會到中國朝貢，最可能與下列哪一件史事有關？', '[{"key":"A","text":"蒙古西征"},{"key":"B","text":"玄奘西行"},{"key":"C","text":"鄭和出使西洋"},{"key":"D","text":"張騫出使西域"}]'::jsonb, '[]'::jsonb, '[[[{"text":"國名","media":[]},{"text":"進貢次數","media":[]}],[{"text":"蘇門答剌（今蘇門答臘島）","media":[]},{"text":"16","media":[]}],[{"text":"榜葛剌（今印度半島孟加拉）","media":[]},{"text":"10","media":[]}],[{"text":"錫蘭山（今斯里蘭卡）","media":[]},{"text":"4","media":[]}],[{"text":"祖法兒（今阿拉伯半島南岸）","media":[]},{"text":"3","media":[]}],[{"text":"木骨都束（今非洲東岸）","media":[]},{"text":"2","media":[]}]]]'::jsonb,
      'C', '', '基測', '102 年',
      'https://knowledgeatlas.cc/history/', array['cn-zhenghe-1405']::text[], 99,
      '原網站事件「鄭和下西洋」自動對應。', 72, 'draft'
    ),
    (
      'ka-jh-set1-s073', 'h4c6-02', 'past',
      '1950 年韓戰爆發，美國政府提供臺灣軍事及經濟援助，對當時物資匱乏、資金短缺的臺灣而言，無疑是一場及時雨。美國當時援助臺灣的根本原因最可能是下列何者？', '[{"key":"A","text":"支援對抗日本的盟國"},{"key":"B","text":"圍堵共產勢力的擴張"},{"key":"C","text":"轉移油價居高不下的焦點"},{"key":"D","text":"防範軍國主義的蔓延"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '100 年',
      'https://knowledgeatlas.cc/history/', array['korea-war-1950']::text[], 99,
      '原網站事件「韓戰」自動對應。', 73, 'draft'
    ),
    (
      'ka-jh-set1-s074', 'h3c4-03', 'past',
      '秀枝近日要交一份有關歷史人物傳記的作業，她蒐集的資料內容有：(１)爪哇有「三寶壠」、「三寶洞」的地名。(２)南海海底發現不少中國瓷器的碎片。(３)今非洲東岸肯亞地區的部落，發現可能有中國人的後裔。從以上的資料，我們可推論秀枝的作業是要寫哪一個人物？', '[{"key":"A","text":"鄭和"},{"key":"B","text":"沈有容"},{"key":"C","text":"顏思齊"},{"key":"D","text":"鄭成功"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第二次基測', '90 年',
      'https://knowledgeatlas.cc/history/', array['cn-zhenghe-1405']::text[], 99,
      '原網站事件「鄭和下西洋」自動對應。', 74, 'draft'
    ),
    (
      'ka-jh-set1-s077', 'h4c4-04', 'past',
      '小禎說：「第二次世界大戰中，美國的參戰是反侵略陣營致勝的關鍵。」小凱問：「為什麼美國會宣戰？」小禎應怎樣回答才符合史實？', '[{"key":"A","text":"為了維持國際均勢"},{"key":"B","text":"因為英國積極求援"},{"key":"C","text":"美國領土受到攻擊"},{"key":"D","text":"因為物資遭受掠奪"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第二次基測', '93 年',
      'https://knowledgeatlas.cc/history/', array['west-wwii-1939', 'jp-pacific-1941']::text[], 99,
      '原網站事件「太平洋戰爭」自動對應。', 77, 'draft'
    ),
    (
      'ka-jh-set1-s079', 'h4c6-02', 'past',
      '西元 1950 年韓戰爆發後，美國對外實施經濟及軍事援助。附圖為 1953 年至 1955 年間美國軍援分配情形圖。我們可以由圖中得出何種資訊？', '[{"key":"A","text":"歐洲對世界的影響力與日遞減"},{"key":"B","text":"美國日漸重視遠東地區的重要性"},{"key":"C","text":"美國對「其他」地區的援助比例日益縮減"},{"key":"D","text":"美國對遠東地區和「其他」地區的援助比例，始終占總援助比例一半以上"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set1-image20.png"]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '96 年',
      'https://knowledgeatlas.cc/history/', array['korea-war-1950']::text[], 99,
      '原網站事件「韓戰」自動對應。', 79, 'draft'
    ),
    (
      'ka-jh-set1-s082', 'h3c2-07', 'past',
      '一本歷史書中對某帝國有以下描述：「這帝國盛行伊斯蘭教，商人擁有能在逆風中航行的商船，從非洲運來黑奴，從印度輸入米、棉及蔗糖，從唐帝國進口絲綢，首都巴格達因此成為當時世界重要的大都會。」此帝國最可能為下列何者？', '[{"key":"A","text":"拜占庭帝國"},{"key":"B","text":"阿拉伯帝國"},{"key":"C","text":"羅馬帝國"},{"key":"D","text":"鄂圖曼帝國"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '100 年',
      'https://knowledgeatlas.cc/history/', array['west-islam-622', 'gs-atlantic-slave', 'cn-tang-cosmopolitan']::text[], 99,
      '原網站事件「唐代多元文化交流」自動對應。', 82, 'draft'
    ),
    (
      'ka-jh-set1-s083', 'h3c2-10', 'past',
      '曉娟到圖書館借了一本書，此書包含「人文主義運動」、「方言文學」、「天才藝術家」、「造紙術與活字印刷術的盛行」四個章節。從這些章節判斷，此書最可能是下列何者？', '[{"key":"A","text":"《希臘城邦文明》"},{"key":"B","text":"《文藝復興時代》"},{"key":"C","text":"《羅馬帝國興亡史》"},{"key":"D","text":"《種姓制度的建立》"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '99 年',
      'https://knowledgeatlas.cc/history/', array['west-renaissance-1350', 'cn-paper']::text[], 99,
      '原網站事件「造紙術改進」自動對應。', 83, 'draft'
    ),
    (
      'ka-jh-set1-s091', 'h3c6-01', 'past',
      '1898 年，紫禁城內發生政變，慈禧太后再度出面掌政，到處搜捕被視為亂黨的改革者，原被裁撤的政府部門和各類官職也重新恢復，軍政大權則由太后信任的權貴控制。下列何者是造成此事件發生的原因？', '[{"key":"A","text":"自強運動"},{"key":"B","text":"百日維新"},{"key":"C","text":"八國聯軍"},{"key":"D","text":"立憲運動"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '100 年',
      'https://knowledgeatlas.cc/history/', array['cn-hundred-days-1898']::text[], 99,
      '原網站事件「戊戌變法」自動對應。', 91, 'draft'
    ),
    (
      'ka-jh-set1-s093', 'h3c5-10', 'past',
      '有位中國官員對外國商人說：「中國並不稀罕西人的奇巧之器，外國人在廣州的生意，每年有幾千萬銀兩的利益，這些都是中國對外國人的恩賜。」這位官員的說法，反映了當時的哪一種思想？', '[{"key":"A","text":"封建思想"},{"key":"B","text":"天朝思想"},{"key":"C","text":"重農思想"},{"key":"D","text":"專賣思想"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '90 年',
      'https://knowledgeatlas.cc/history/', array['cn-canton-1757']::text[], 96,
      '依題幹與答案複核：題目描述廣州一口通商下的天朝觀念。', 93, 'draft'
    ),
    (
      'ka-jh-set1-s094', 'h3c5-06', 'past',
      '美秀為了寫歷史報告，蒐集李鴻章、曾國藩等人的資料，南京兵工廠的照片，以及第一批出國留學幼童的合照。依此推斷，她要寫的主題最可能與下列何者有關？', '[{"key":"A","text":"鴉片戰爭"},{"key":"B","text":"自強運動"},{"key":"C","text":"甲午戰爭"},{"key":"D","text":"戊戌變法"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '96 年',
      'https://knowledgeatlas.cc/history/', array['cn-selfstrength-1861']::text[], 99,
      '原網站事件「自強運動」自動對應。', 94, 'draft'
    ),
    (
      'ka-jh-set1-s095', 'h3c5-06', 'past',
      '清代某大臣上奏：「兩年前，我們選送六位廣方言館學生到北京考試，後來總理衙門來函稱讚這六名學生表現卓越，現已授予這些學生『翻譯貢生』的資格。有鑒於新開埠的港口及地方上新建的學堂亟需人才，將由這批學生來擔任相關職務。」這份奏摺所陳述的情況最可能發生在下列何時？', '[{"key":"A","text":"流寇之亂期間"},{"key":"B","text":"鴉片戰爭之時"},{"key":"C","text":"自強運動期間"},{"key":"D","text":"戊戌變法期間"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第一次基測', '98 年',
      'https://knowledgeatlas.cc/history/', array['cn-selfstrength-1861']::text[], 99,
      '原網站事件「自強運動」自動對應。', 95, 'draft'
    ),
    (
      'ka-jh-set1-s099', 'h4c5-09', 'past',
      '「西元 1989 年，成千上萬的學生在北京市中心的天安門廣場集會，表達對國家領導的不滿，並要求民主改革……。」文中的事件發生在附圖哪一個地區？', '[{"key":"A","text":"甲"},{"key":"B","text":"乙"},{"key":"C","text":"丙"},{"key":"D","text":"丁"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set1-image24.png"]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '95 年',
      'https://knowledgeatlas.cc/history/', array['cn-tiananmen-1989']::text[], 99,
      '原網站事件「六四天安門事件」自動對應。', 99, 'draft'
    ),
    (
      'ka-jh-set1-s103', 'h3c1-02', 'past',
      '封建制度是鞏固周代政治社會秩序的主要力量，但當時仍須以禮樂配合下列哪一項制度，才得以維繫運作？', '[{"key":"A","text":"太學制度"},{"key":"B","text":"察舉制度"},{"key":"C","text":"郡縣制度"},{"key":"D","text":"宗法制度"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '第一次基測', '93 年',
      'https://knowledgeatlas.cc/history/', array['cn-feudal-1046']::text[], 99,
      '原網站事件「西周封建制度」自動對應。', 103, 'draft'
    ),
    (
      'ka-jh-set1-s106', 'h3c6-01', 'past',
      '李泉是清末民初的知識分子，他認為中國的未來，應要順應時勢潮流而作改變，主張以光緒帝為首，改革舊制、增新機構、廣納建言。依此判斷，他最可能參與下列哪一項運動？', '[{"key":"A","text":"自強運動"},{"key":"B","text":"百日維新"},{"key":"C","text":"立憲運動"},{"key":"D","text":"庚子後新政"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '95 年',
      'https://knowledgeatlas.cc/history/', array['cn-hundred-days-1898']::text[], 99,
      '原網站事件「戊戌變法」自動對應。', 106, 'draft'
    ),
    (
      'ka-jh-set1-s110', 'h4c3-02', 'past',
      '陳奶奶回憶說：「在那個年代，市面流通著各種貨幣，後來政府廢除銀兩，規定一律改用銀元；再過一陣子，政府規定只能用指定銀行發行的紙幣，終於解除了幣制混亂的局面。」陳奶奶描述的應是下列哪一時期？', '[{"key":"A","text":"民國 17～26 年十年建設"},{"key":"B","text":"民國 26～34 年八年抗戰"},{"key":"C","text":"民國 34～38 年國共內戰"},{"key":"D","text":"民國 62～68 年十大建設"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第一次基測', '93 年',
      'https://knowledgeatlas.cc/history/', array['cn-nanjing-decade']::text[], 99,
      '原網站事件「十年建設」自動對應。', 110, 'draft'
    ),
    (
      'ka-jh-set1-s113', 'h3c6-01', 'past',
      '清末國局動盪不安，為救亡圖存，有識人士提出變法改革主張，但都未能成功，重要的原因之一在於保守派的反對。下列哪一位為當時最具影響力的保守派人物？', '[{"key":"A","text":"李鴻章"},{"key":"B","text":"慈禧太后"},{"key":"C","text":"德宗光緒帝"},{"key":"D","text":"恭親王奕訢"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '92 年',
      'https://knowledgeatlas.cc/history/', array['cn-shangyang-356bc', 'cn-hundred-days-1898']::text[], 99,
      '原網站事件「戊戌變法」自動對應。', 113, 'draft'
    ),
    (
      'ka-jh-set1-s116', 'h4c3-07', 'past',
      '八年抗戰前，中共為了解除來自國民政府的威脅，提出「自己人不打自己人」、「停止內戰一致抗日」等口號，影響當時擔任西北剿共主力的指揮官，由該軍官發動軍變，改變日後政局的發展。這是史上哪一事件？', '[{"key":"A","text":"九一八事變"},{"key":"B","text":"二二八事件"},{"key":"C","text":"西安事變"},{"key":"D","text":"牡丹社事件"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第二次基測', '92 年',
      'https://knowledgeatlas.cc/history/', array['cn-xian-1936', 'cn-warjapan-1937']::text[], 99,
      '依題幹與答案複核：題目直接詢問西安事變。', 116, 'draft'
    ),
    (
      'ka-jh-set1-s126', 'h3c2-07', 'past',
      '章回小說《西遊記》敘述唐三藏、孫悟空等人去印度取經的故事，這是根據哪一個人西行的故事發展而來？', '[{"key":"A","text":"張騫"},{"key":"B","text":"商鞅"},{"key":"C","text":"玄奘"},{"key":"D","text":"鄭和"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第一次基測', '91 年',
      'https://knowledgeatlas.cc/history/', array['cn-tang-cosmopolitan']::text[], 99,
      '原網站事件「唐代多元文化交流」自動對應。', 126, 'draft'
    ),
    (
      'ka-jh-set1-s128', 'h4c1-01', 'past',
      '外國的報紙曾對中國某事件有以下報導：「四川保路同志會所引發的星星之火，終於燎原了。流亡海外的反清領袖孫中山可能被推選為民國總統。」這最可能是針對下列何者所做的報導？', '[{"key":"A","text":"辛亥革命"},{"key":"B","text":"聯俄容共"},{"key":"C","text":"二次革命"},{"key":"D","text":"護法運動"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第二次基測', '100 年',
      'https://knowledgeatlas.cc/history/', array['cn-1911']::text[], 99,
      '原網站事件「武昌起義與辛亥革命」自動對應。', 128, 'draft'
    ),
    (
      'ka-jh-set1-s144', 'h3c3-06', 'past',
      '老師講述中國歷史時說到：「這個民族是中國歷代邊疆民族中，漢化程度較淺的民族之一。他們入主中國後，為了保持統治地位，各級長官甚少任用漢族人士，對漢人、南人採取高度控制的態度及手段，結果引起漢人、南人的不滿與反抗。」老師介紹的是下列哪一民族？', '[{"key":"A","text":"鮮卑族"},{"key":"B","text":"契丹族"},{"key":"C","text":"蒙古族"},{"key":"D","text":"女真族"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '試辦會考', '102 年',
      'https://knowledgeatlas.cc/history/', array['cn-mongol-conquest']::text[], 92,
      '原網站事件「蒙古擴張與元朝統一」自動對應。', 144, 'draft'
    ),
    (
      'ka-jh-set1-s146', 'h4c2-01', 'past',
      '中國歷史上某一時期，曾有教授和大學生主張以口語化的新文學取代舊式古典文學，並有意識地反對許多傳統觀念與習俗，將男女個人從傳統束縛中解放出來。這樣的主張應出現於下列何時？', '[{"key":"A","text":"自強運動"},{"key":"B","text":"百日維新"},{"key":"C","text":"十年建設"},{"key":"D","text":"新文化運動"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '第二次基測', '98 年',
      'https://knowledgeatlas.cc/history/', array['cn-newculture-1915']::text[], 99,
      '原網站事件「新文化運動」自動對應。', 146, 'draft'
    ),
    (
      'ka-jh-set1-s153', 'h4c3-02', 'past',
      '在王爺爺收藏的舊紙幣中，恰好有同一年由國民政府在中國大陸先後發行的三種紙幣（如附圖）。從紙幣發行面額的變化，可推知當時的經濟情形為何？', '[{"key":"A","text":"國家強盛，紙幣的價值升高"},{"key":"B","text":"通貨膨脹，貨幣購買力變低"},{"key":"C","text":"經濟發達，貨幣需求量大增"},{"key":"D","text":"物資缺乏，製幣的成本增加"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set1-image33.png"]'::jsonb, '[]'::jsonb,
      'B', '', '第二次基測', '91 年',
      'https://knowledgeatlas.cc/history/', array['cn-nanjing-decade']::text[], 99,
      '原網站事件「十年建設」自動對應。', 153, 'draft'
    ),
    (
      'ka-jh-set1-s164', 'h4c5-05', 'past',
      '有一部電影劇情如下：「祥子回到故鄉，那裡充斥著『破四舊』的標語，他看到村長被畫分為『地主』階級而遭受殘酷的公審。後來，祥子的妻子難產，醫院裡的醫生們卻已在『打倒學術權威』的口號下被迫離開……。」這部電影的時空背景最可能是下列何者？', '[{"key":"A","text":"國共內戰下的臺灣"},{"key":"B","text":"軍閥混戰時期的華北"},{"key":"C","text":"滿洲國成立後的東北"},{"key":"D","text":"文化大革命時期的中國"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '第一次基測', '99 年',
      'https://knowledgeatlas.cc/history/', array['cn-culturalrev-1966']::text[], 99,
      '原網站事件「文化大革命」自動對應。', 164, 'draft'
    ),
    (
      'ka-jh-set1-s172', 'h3c5-06', 'past',
      '清朝年間，有大臣上奏，建議朝廷選擇聰穎幼童，將他們送到西方各國學習軍政、船政、數學、製造等學問，十餘年後，當幼童學成歸國並貢獻所學，中國便能熟悉西方技術，國家可以逐漸壯大。朝廷同意此一建議，將其頒布施行。上述情況最早應出現於下列何時？', '[{"key":"A","text":"鴉片戰爭期間"},{"key":"B","text":"自強運動期間"},{"key":"C","text":"戊戌變法之際"},{"key":"D","text":"新文化運動後"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第二次基測', '100 年',
      'https://knowledgeatlas.cc/history/', array['cn-selfstrength-1861']::text[], 99,
      '原網站事件「自強運動」自動對應。', 172, 'draft'
    ),
    (
      'ka-jh-set1-s177', 'h3c1-05', 'past',
      '下列是一部歷史電影的部分劇情簡介：「一位好大喜功的君主，改用皇帝的稱號來榮耀自己偉大的功業，並採取嚴厲的法律措施以推行中央集權與文化統一政策，動用龐大的人力興建浩大的工程，然而卻因此走向滅亡之路。」這應是描述哪一位君主事蹟的電影？', '[{"key":"A","text":"秦始皇"},{"key":"B","text":"漢武帝"},{"key":"C","text":"唐太宗"},{"key":"D","text":"北魏孝文帝"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第二次基測', '91 年',
      'https://knowledgeatlas.cc/history/', array['cn-unification-221bc']::text[], 99,
      '原網站事件「秦統一與中央集權」自動對應。', 177, 'draft'
    ),
    (
      'ka-jh-set1-s181', 'h3c2-03', 'past',
      '小明暑假遠赴中國西北地區旅遊，途經河西走廊、天山一帶直到伊犁河附近。回來後，他以這次旅程中的見聞為主題撰寫心得報告，下列何者最可能出現在其中？', '[{"key":"A","text":"「絲路」的交通路程"},{"key":"B","text":"鄭和出使的遠行路線"},{"key":"C","text":"八國聯軍的進攻地點"},{"key":"D","text":"蒙古西征過程"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第二次基測', '94 年',
      'https://knowledgeatlas.cc/history/', array['cn-silkroad']::text[], 94,
      '原網站事件「張騫通西域與絲路交流」自動對應。', 181, 'draft'
    ),
    (
      'ka-jh-set1-s186', 'h3c3-08', 'past',
      '附圖是小農籌備班上話劇表演的企畫書，由內容推斷，下列哪一種情境最可能出現在其中？', '[{"key":"A","text":"夜市通宵達旦，各種貨物琳瑯滿目"},{"key":"B","text":"美洲白銀流入，賦稅貨款以銀繳納"},{"key":"C","text":"凡事仰賴占卜，將占卜結果記在甲骨上"},{"key":"D","text":"婦女穿著胡服，自由穿梭於大街小巷間"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set1-image43.png"]'::jsonb, '[]'::jsonb,
      'A', '', '第二次基測', '97 年',
      'https://knowledgeatlas.cc/history/', array['cn-maritime-song']::text[], 99,
      '原網站事件「宋元海上貿易」自動對應。', 186, 'draft'
    ),
    (
      'ka-jh-set1-s188', 'h4c5-05', 'past',
      '「當時中央鼓吹『破四舊』，許多地主、知識分子頭上戴著紙做的高帽子，上面寫著『黑幫頭子』、『反動權威』等字樣，被推出去遊街示眾，受到人民的唾罵……。」上段文字是描述發生在中共統治下的哪一件事？', '[{"key":"A","text":"大躍進"},{"key":"B","text":"改革開放"},{"key":"C","text":"文化大革命"},{"key":"D","text":"土地改革"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第一次基測', '96 年',
      'https://knowledgeatlas.cc/history/', array['cn-culturalrev-1966']::text[], 99,
      '原網站事件「文化大革命」自動對應。', 188, 'draft'
    ),
    (
      'ka-jh-set1-s199', 'h4c2-01', 'past',
      '民國初年新文化運動期間，許多知識分子主張全盤西化以拯救中國，這種主張的基本精神為何？', '[{"key":"A","text":"以儒家思想為指導，酌量採用西方體制與科技"},{"key":"B","text":"改革舊有專制政治，提倡君主立憲實施國會民主"},{"key":"C","text":"推翻舊倫理和舊道德，效法西方的民主與科學精神"},{"key":"D","text":"廣泛閱讀西方文學著作，飲食起居全面採西式作風"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第二次基測', '93 年',
      'https://knowledgeatlas.cc/history/', array['cn-newculture-1915']::text[], 99,
      '原網站事件「新文化運動」自動對應。', 199, 'draft'
    ),
    (
      'ka-jh-set1-s200', 'h3c4-04', 'past',
      '明初與清初的統治者，都面臨來自東南沿海的威脅。明代初年，東南沿海一帶海盜為患；而清代初期，則有臺灣島上鄭氏政權抗清的行動。兩者面對的問題雖有差異，但明太祖與清聖祖都選擇了相同的處理方式。此一「處理方式」應為下列何者？（註：實邊：充實、開發邊遠地區。）', '[{"key":"A","text":"開港通商"},{"key":"B","text":"移民實邊"},{"key":"C","text":"開山撫番"},{"key":"D","text":"實施海禁"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '第一次基測', '98 年',
      'https://knowledgeatlas.cc/history/', array['tw-zheng-policy', 'cn-haijin']::text[], 99,
      '原網站事件「明代海禁」自動對應。', 200, 'draft'
    ),
    (
      'ka-jh-set1-s209', 'h4c4-07', 'past',
      '第二次世界大戰結束後，國共內戰，國民政府遷臺，遷臺之初兩岸局勢緊張，但因為哪一事件，促使美國派遣第七艦隊保衛臺灣海峽安全，才穩定了臺海局勢？', '[{"key":"A","text":"韓戰"},{"key":"B","text":"越戰"},{"key":"C","text":"古寧頭戰役"},{"key":"D","text":"八二三炮戰"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第一次基測', '92 年',
      'https://knowledgeatlas.cc/history/', array['west-wwii-end-1945', 'west-wwii-1939', 'china-civilwar-1946']::text[], 96,
      '原網站事件「國共內戰與兩岸分治」自動對應。', 209, 'draft'
    ),
    (
      'ka-jh-set1-s218', 'h3c2-07', 'past',
      '唐朝劉禹錫詩：「朱雀橋邊野草花，烏衣巷口夕陽斜，舊時王謝堂前燕，飛入尋常百姓家。」類似王、謝這些世家大族的沒落，除與政治上的動亂有關外，亦與下列哪一項制度的廢除有關？', '[{"key":"A","text":"封建制度"},{"key":"B","text":"孝廉選官"},{"key":"C","text":"九品官人之法"},{"key":"D","text":"科舉制度"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第二次基測', '93 年',
      'https://knowledgeatlas.cc/history/', array['cn-nine-rank-220', 'cn-tang-cosmopolitan']::text[], 99,
      '原網站事件「唐代多元文化交流」自動對應。', 218, 'draft'
    ),
    (
      'ka-jh-set1-s226', 'h4c2-03', 'past',
      '一封發給北京某報社的電報，主要內容如下：「……學生為了山東問題，向曹、章、陸等官員進行示威，部分官員受傷嚴重，政府因此傾向判處學生死刑，並解散大學。……有人認為學生只是出自愛國熱誠，並沒有別的企圖，即使有過失，也是可以原諒的。」這封電報應是為下列哪一事件而發的？', '[{"key":"A","text":"五四運動"},{"key":"B","text":"西安事變"},{"key":"C","text":"文化大革命"},{"key":"D","text":"六四天安門事件"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第一次基測', '92 年',
      'https://knowledgeatlas.cc/history/', array['china-mayfourth-1919']::text[], 99,
      '原網站事件「五四運動」自動對應。', 226, 'draft'
    ),
    (
      'ka-jh-set1-s227', 'h3c5-06', 'past',
      '1860 年代是近代世界重大的變革時期，在這期間，北美洲的美國因區域產業發展型態的差異，國內在國家發展方針上出現歧見，引發嚴重的軍事對抗；亞洲的中國則因貿易與文化上的問題，與歐洲國家發生多次衝突，失利的清朝被迫推行改革；歐洲的義大利及日耳曼地區，則因民族主義的興起，出現建國運動，企圖克服外來阻礙，促成國家統一。上述清朝推行的「改革」，最可能是指下列何者？', '[{"key":"A","text":"自強運動"},{"key":"B","text":"戊戌變法"},{"key":"C","text":"立憲運動"},{"key":"D","text":"庚子後新政"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第二次基測', '99 年',
      'https://knowledgeatlas.cc/history/', array['cn-selfstrength-1861']::text[], 99,
      '原網站事件「自強運動」自動對應。', 227, 'draft'
    ),
    (
      'ka-jh-set1-s228', 'h4c2-01', 'past',
      '17 世紀歐洲的「科學革命」改變了西方人的思考與生活方式，科學知識逐漸成為西方人努力追求的方向。這種對科學的重視與提倡，在下列哪一時期普遍地影響了中國的知識分子，並被大力宣揚？', '[{"key":"A","text":"清末百日維新"},{"key":"B","text":"民初新文化運動"},{"key":"C","text":"北伐後十年建設"},{"key":"D","text":"中共文化大革命"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第一次基測', '94 年',
      'https://knowledgeatlas.cc/history/', array['cn-newculture-1915', 'west-scientific-1543']::text[], 99,
      '原網站事件「新文化運動」自動對應。', 228, 'draft'
    ),
    (
      'ka-jh-set1-s230', 'h3c4-03', 'past',
      '小宇蒐集鄭和、達伽馬、哥倫布、麥哲倫四人的生平事蹟寫了一篇報告，他想為這篇報告下個標題，下列哪一個最適合？', '[{"key":"A","text":"「熱衷研究的科學家」"},{"key":"B","text":"「英勇的海外探險家」"},{"key":"C","text":"「真情流露的文學家」"},{"key":"D","text":"「憂國憂民的政治家」"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第二次基測', '96 年',
      'https://knowledgeatlas.cc/history/', array['west-exploration-1492', 'cn-zhenghe-1405']::text[], 99,
      '原網站事件「鄭和下西洋」自動對應。', 230, 'draft'
    ),
    (
      'ka-jh-set1-s234', 'h3c5-05', 'past',
      '近代中國的對外關係，由閉關自守走向商埠開放、由宗藩關係步入國際社會，這是從哪一個戰爭開始的？', '[{"key":"A","text":"鴉片戰爭"},{"key":"B","text":"清法戰爭"},{"key":"C","text":"甲午戰爭"},{"key":"D","text":"八國聯軍"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第一次基測', '90 年',
      'https://knowledgeatlas.cc/history/', array['cn-opium-1840', 'tw-shimonoseki-1895']::text[], 99,
      '原網站事件「鴉片戰爭」自動對應。', 234, 'draft'
    ),
    (
      'ka-jh-set1-s235', 'h3c4-04', 'past',
      '對於中國史上某朝代後期的商貿情況，歷史書中有以下描述：「部分商人在中國沿海從事貿易活動，運送絲綢、茶葉等貨品到呂宋等地販售，以賺取白銀。運貨途中，他們得冒著遭海盜劫掠的風險，有時因為違反禁令，也須躲避官府的查緝。」此一朝代最可能是下列何者？（註：呂宋＝今菲律賓）', '[{"key":"A","text":"唐代"},{"key":"B","text":"宋代"},{"key":"C","text":"元代"},{"key":"D","text":"明代"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '第一次基測', '99 年',
      'https://knowledgeatlas.cc/history/', array['cn-haijin']::text[], 99,
      '原網站事件「明代海禁」自動對應。', 235, 'draft'
    ),
    (
      'ka-jh-set1-s236', 'h4c3-04', 'past',
      '「學校師生要向日本天皇及當時在位的滿皇帝遙拜，唱國歌，背誦溥儀的詔書，且學生必須學習日語，並被灌輸『日滿一體』的思想。」上述情況最可能發生於下列何時何地？', '[{"key":"A","text":"1915 年的臺北"},{"key":"B","text":"1920 年的香港"},{"key":"C","text":"1940 年的瀋陽"},{"key":"D","text":"1945 年的重慶"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第一次基測', '100 年',
      'https://knowledgeatlas.cc/history/', array['cn-manchuria-1931']::text[], 99,
      '原網站事件「九一八事變」自動對應。', 236, 'draft'
    ),
    (
      'ka-jh-set1-s238', 'h3c2-03', 'past',
      '附圖是漢代疆域圖。當時疆域能拓展至甲區，主要和下列哪一位歷史人物的事蹟有關？', '[{"key":"A","text":"張騫"},{"key":"B","text":"商鞅"},{"key":"C","text":"玄奘"},{"key":"D","text":"嬴政"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set1-image55.png"]'::jsonb, '[]'::jsonb,
      'A', '', '第二次基測', '96 年',
      'https://knowledgeatlas.cc/history/', array['cn-silkroad']::text[], 94,
      '原網站事件「張騫通西域與絲路交流」自動對應。', 238, 'draft'
    ),
    (
      'ka-jh-set1-s239', 'h3c5-05', 'past',
      '清末，列強曾在中國取得租界，且獲有領事裁判權，各國在其租界內便享有自主的司法、經濟與行政等權利，清廷無法以法律規範這些外國人士。根據上述內容，下列哪一項敘述最符合其意涵？', '[{"key":"A","text":"國家主權的行使受到破壞"},{"key":"B","text":"司法權與行政權相互制衡"},{"key":"C","text":"畫定租界推廣中西文化的交流"},{"key":"D","text":"經濟發展受到國際組織的限制"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第一次基測', '99 年',
      'https://knowledgeatlas.cc/history/', array['cn-opium-1840']::text[], 99,
      '原網站事件「鴉片戰爭」自動對應。', 239, 'draft'
    ),
    (
      'ka-jh-set1-s240', 'h3c2-11', 'past',
      '艾玲參加學校的日語社，老師說日文是模仿中國文字而製成。日文的製成與下列哪一背景有關？', '[{"key":"A","text":"大化革新"},{"key":"B","text":"幕府政治"},{"key":"C","text":"鎖國政策"},{"key":"D","text":"明治維新"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第一次基測', '92 年',
      'https://knowledgeatlas.cc/history/', array['jp-taika-646', 'cn-tang-cosmopolitan']::text[], 99,
      '依題幹與答案複核：題目答案為大化革新。', 240, 'draft'
    ),
    (
      'ka-jh-set1-s246', 'h3c5-06', 'past',
      '清末推行自強運動，總理各國事務衙門是當時成立的第一個新機構。該機構最初設立的目的最可能為下列何者？', '[{"key":"A","text":"裁決司法案件"},{"key":"B","text":"籌辦議會政治"},{"key":"C","text":"辦理外交事宜"},{"key":"D","text":"籠絡境內民族"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '基測', '101 年',
      'https://knowledgeatlas.cc/history/', array['cn-selfstrength-1861']::text[], 99,
      '原網站事件「自強運動」自動對應。', 246, 'draft'
    ),
    (
      'ka-jh-set1-s253', 'h3c2-11', 'past',
      '不同文化的接觸，往往會造成彼此衝突矛盾或互相融合創新等現象，以下列四件史事為例，何者最適合做為文化融合成功的例證？', '[{"key":"A","text":"大化革新"},{"key":"B","text":"雍正禁教"},{"key":"C","text":"義和團事件"},{"key":"D","text":"文化大革命"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '第二次基測', '95 年',
      'https://knowledgeatlas.cc/history/', array['jp-taika-646', 'cn-tang-cosmopolitan']::text[], 99,
      '依題幹與答案複核：題目答案為大化革新。', 253, 'draft'
    ),
    (
      'ka-jh-set1-s255', 'h4c2-01', 'past',
      '民初新文化運動期間，有人反對中國傳統思想與制度，並主張全盤西化。在此種風氣下，如果當時市面上有下列四本書，哪一本較易受到全盤西化論者所排斥？', '[{"key":"A","text":"《科技與社會改造》"},{"key":"B","text":"《民主主義在中國》"},{"key":"C","text":"《儒家文化思想精義》"},{"key":"D","text":"《馬克思的世界革命》"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第二次基測', '90 年',
      'https://knowledgeatlas.cc/history/', array['cn-newculture-1915']::text[], 99,
      '原網站事件「新文化運動」自動對應。', 255, 'draft'
    ),
    (
      'ka-jh-set1-s259', 'h3c3-08', 'past',
      '歷史資料的種類繁多，畫作也是其中之一。附圖是張擇端繪製的《清明上河圖》部分內容，參考這幅圖將最有助於研究下列哪一主題？', '[{"key":"A","text":"漢代的鄉村生活"},{"key":"B","text":"大唐的繁華京城"},{"key":"C","text":"宋人的城市生活"},{"key":"D","text":"明初的園林造景"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set1-image60.png"]'::jsonb, '[]'::jsonb,
      'C', '', '第二次基測', '96 年',
      'https://knowledgeatlas.cc/history/', array['cn-maritime-song']::text[], 99,
      '原網站事件「宋元海上貿易」自動對應。', 259, 'draft'
    ),
    (
      'ka-jh-set1-s262', 'h4c5-07', 'past',
      '附圖呈現中國 1952 年至 2005 年國內生產毛額的數據資料。圖中曲線從甲處後有明顯變動的情況，最可能與下列何者有關？', '[{"key":"A","text":"利用韓戰爆發契機，提高進口關稅"},{"key":"B","text":"大躍進提倡生產，民眾盡全力煉鋼"},{"key":"C","text":"發動文化大革命，進行全面的改造"},{"key":"D","text":"實施改革開放政策，引進外來資金"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set1-image62.png"]'::jsonb, '[]'::jsonb,
      'D', '', '基測', '102 年',
      'https://knowledgeatlas.cc/history/', array['cn-reform-1978']::text[], 99,
      '原網站事件「改革開放」自動對應。', 262, 'draft'
    ),
    (
      'ka-jh-set1-g06-q1', 'h3c5-05', 'past',
      '這座城市鄰近長江出海口，清末開港通商以來，逐漸形成二大區域：中國政府管轄的老城區與外國人主導治理的租界區，租界區的外國人享有行政與經濟等獨立自主權，可自組行政機構，並在租界區徵稅。八年抗戰爆發後，因為西方國家保持中立，日軍原則上不能進入西方國家租界區內，所以該地區仍享有特權和保障。但後來某事爆發，不但造成美、英等國對日宣戰，日本也進兵西方國家租界區，侵占外國企業，進一步控制該城市。

上文所述的城市，最可能位於附圖中甲、乙、丙、丁何處？', '[{"key":"A","text":"甲"},{"key":"B","text":"乙"},{"key":"C","text":"丙"},{"key":"D","text":"丁"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set1-image66.png"]'::jsonb, '[]'::jsonb,
      'B', '', '基測', '102 年',
      'https://knowledgeatlas.cc/history/', array['cn-warjapan-1937', 'cn-opium-1840', 'jp-pacific-1941']::text[], 94,
      '依題幹與答案複核：題組以開港後上海租界為背景。', 6, 'draft'
    ),
    (
      'ka-jh-set1-g06-q2', 'h3c5-05', 'past',
      '這座城市鄰近長江出海口，清末開港通商以來，逐漸形成二大區域：中國政府管轄的老城區與外國人主導治理的租界區，租界區的外國人享有行政與經濟等獨立自主權，可自組行政機構，並在租界區徵稅。八年抗戰爆發後，因為西方國家保持中立，日軍原則上不能進入西方國家租界區內，所以該地區仍享有特權和保障。但後來某事爆發，不但造成美、英等國對日宣戰，日本也進兵西方國家租界區，侵占外國企業，進一步控制該城市。

根據上文，該城市「二大區域」的不同管轄情況，最主要反映出下列哪一現象？', '[{"key":"A","text":"形成區域統合"},{"key":"B","text":"維護多元文化"},{"key":"C","text":"政府分權制衡"},{"key":"D","text":"主權受到破壞"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '基測', '102 年',
      'https://knowledgeatlas.cc/history/', array['cn-warjapan-1937', 'cn-opium-1840', 'jp-pacific-1941']::text[], 94,
      '依題幹與答案複核：題組考查開港與租界造成的主權損害。', 6, 'draft'
    ),
    (
      'ka-jh-set1-g06-q3', 'h4c4-04', 'past',
      '這座城市鄰近長江出海口，清末開港通商以來，逐漸形成二大區域：中國政府管轄的老城區與外國人主導治理的租界區，租界區的外國人享有行政與經濟等獨立自主權，可自組行政機構，並在租界區徵稅。八年抗戰爆發後，因為西方國家保持中立，日軍原則上不能進入西方國家租界區內，所以該地區仍享有特權和保障。但後來某事爆發，不但造成美、英等國對日宣戰，日本也進兵西方國家租界區，侵占外國企業，進一步控制該城市。

上文所提的某事，應為下列何者？', '[{"key":"A","text":"九一八事變"},{"key":"B","text":"西安事變"},{"key":"C","text":"盧溝橋事變"},{"key":"D","text":"珍珠港事件"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '基測', '102 年',
      'https://knowledgeatlas.cc/history/', array['cn-warjapan-1937', 'jp-pacific-1941']::text[], 99,
      '依題幹與答案複核：題目答案為珍珠港事件。', 6, 'draft'
    ),
    (
      'ka-jh-set1-g07-q1', 'h3c5-09', 'past',
      '下列是有關圓明園遭到破壞的部分文獻資料──
資料一：「這些宮殿非常龐大，由於我們必須在限定時間內完成任務，使我們無法澈底地掠奪。」
資料二：「最近夷人遍布在城內，任意進出皇宮，到處搶劫財物，汙辱婦女，殺傷民眾，無法無天。」
資料三：「圓明園的焚掠，在人類文化史上的損失是無法估計的，不但毀滅了世上獨一無二的名園，而且損失了中國歷代珍藏下來的文物。」
資料四：「我們號稱自己是文明人，認為中國人是野蠻人；這就是文明人對野蠻人所幹的好事！」

上述事件發生在下列哪一場戰爭期間？', '[{"key":"A","text":"鴉片戰爭"},{"key":"B","text":"英法聯軍"},{"key":"C","text":"甲午戰爭"},{"key":"D","text":"清法戰爭"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '第二次基測', '97 年',
      'https://knowledgeatlas.cc/history/', array['cn-arrowwar-1856']::text[], 99,
      '原網站事件「英法聯軍」自動對應。', 7, 'draft'
    ),
    (
      'ka-jh-set1-g07-q2', 'h3c5-09', 'past',
      '下列是有關圓明園遭到破壞的部分文獻資料──
資料一：「這些宮殿非常龐大，由於我們必須在限定時間內完成任務，使我們無法澈底地掠奪。」
資料二：「最近夷人遍布在城內，任意進出皇宮，到處搶劫財物，汙辱婦女，殺傷民眾，無法無天。」
資料三：「圓明園的焚掠，在人類文化史上的損失是無法估計的，不但毀滅了世上獨一無二的名園，而且損失了中國歷代珍藏下來的文物。」
資料四：「我們號稱自己是文明人，認為中國人是野蠻人；這就是文明人對野蠻人所幹的好事！」

對上述資料的詮釋，下列何者最合理？', '[{"key":"A","text":"資料一是防守宮殿的清軍將領的日記"},{"key":"B","text":"資料二是當時駐北京英國使節的記載"},{"key":"C","text":"資料三是後人對這段歷史的批判省思"},{"key":"D","text":"資料四是西方帝國主義者侵略的藉口"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '第二次基測', '97 年',
      'https://knowledgeatlas.cc/history/', array['cn-arrowwar-1856']::text[], 99,
      '原網站事件「英法聯軍」自動對應。', 7, 'draft'
    ),
    (
      'ka-jh-set2-s003', 'h4c2-03', 'past',
      '圖(一)是某旅遊手冊的部分內容，此手冊最可能是介紹圖(二)中的何地？', '[{"key":"A","text":"甲"},{"key":"B","text":"乙"},{"key":"C","text":"丙"},{"key":"D","text":"丁"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image3.png","https://knowledgeatlas.cc/history/assets/history-exams/set2-image4.png"]'::jsonb, '[[[{"text":"","media":["assets/history-exams/set2-image3.png"]},{"text":"","media":["assets/history-exams/set2-image4.png"]}],[{"text":"▲圖(一)","media":[]},{"text":"▲圖(二)","media":[]}]]]'::jsonb,
      'B', '', '會考', '104 年',
      'https://knowledgeatlas.cc/history/', array['west-ww1-1914', 'jp-21demands-1915', 'china-mayfourth-1919']::text[], 99,
      '原網站事件「五四運動」自動對應。', 3, 'draft'
    ),
    (
      'ka-jh-set2-s005', 'h3c5-05', 'past',
      '附圖是某時期上海報刊上所刊載的時事報導，此一報導最可能是在描繪下列何時的情景？', '[{"key":"A","text":"十六世紀前期"},{"key":"B","text":"十七世紀後期"},{"key":"C","text":"十八世紀前期"},{"key":"D","text":"十九世紀後期"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image5.png"]'::jsonb, '[]'::jsonb,
      'D', '', '會考補考', '111 年',
      'https://knowledgeatlas.cc/history/', array['cn-opium-1840']::text[], 99,
      '原網站事件「鴉片戰爭」自動對應。', 5, 'draft'
    ),
    (
      'ka-jh-set2-s008', 'h3c4-05', 'past',
      '日本料理「天婦羅」，是將食材裹上澱粉漿之後下鍋油炸，這種料理源自於天主教徒在齋戒期間，將食材油炸後食用。在沒有冷凍技術的時代，因為油炸食物容易保存，所以水手於遠洋航行時也會準備油炸魚類作為糧食。葡萄牙的天主教徒最初到日本傳教與貿易時，同時傳入這種料理。「天婦羅」傳入日本的時代背景，最可能是下列何者？', '[{"key":"A","text":"外國艦隊脅迫幕府開港，促使日本推動明治維新"},{"key":"B","text":"西方各國展開海外探險，建立到達東方的新航線"},{"key":"C","text":"日本受大唐文化的薰染，效法唐朝推動制度改革"},{"key":"D","text":"民主陣營為防堵共產勢力，派遣艦隊駐防太平洋"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '111 年',
      'https://knowledgeatlas.cc/history/', array['west-exploration-1492', 'jp-europeans-1543', 'cn-macau-1557']::text[], 90,
      '原網站事件「日本戰國與歐洲人來航」自動對應。', 8, 'draft'
    ),
    (
      'ka-jh-set2-s009', 'h3c3-02', 'past',
      '下列為西元十一世紀，甲、乙二國針對當前外交情勢的看法：
甲國：每年從乙國獲得的銀兩、絹帛為本國皇帝和貴族所有，人民亦可透過貿易取得所需物資，與乙國維持和平，獲益良多。
乙國：每年付給甲國的歲幣雖是一項負擔，但比起之前兩國交戰時的軍事費用，不過百分之一、二。
上述內容應與下列何者有關？', '[{"key":"A","text":"宋遼締結澶淵之盟，此後以兄弟相稱"},{"key":"B","text":"唐朝因國力強盛，吸引各國遣使交流"},{"key":"C","text":"中日簽署《馬關條約》，中國割地賠款"},{"key":"D","text":"明朝派鄭和下西洋，促使外邦前來朝貢"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '會考陸考', '112 年',
      'https://knowledgeatlas.cc/history/', array['cn-chanyuan-1005']::text[], 99,
      '原網站事件「澶淵之盟」自動對應。', 9, 'draft'
    ),
    (
      'ka-jh-set2-s010', 'h4c5-05', 'past',
      '1960 年代是一個社會內部衝突與對抗的年代。在此期間，美國種族衝突日益激烈，為了對抗種族隔離措施，黑人民權運動在各地展開，促使國會通過法案，確保少數族裔獲得在法律及政治上的平等地位；中國則因領導階層的權力爭奪，鼓動青年學生，在「革命無罪、造反有理」的口號下，展開一連串的破壞行動；捷克領導人提倡改革，放寬經濟與政治的管制，受到廣大民眾的支持，但「老大哥」嚴厲禁止其改革，領導華沙公約組織出兵捷克，加以鎮壓。上文所述的「老大哥」，最可能是下列何者？', '[{"key":"A","text":"蘇聯"},{"key":"B","text":"美國"},{"key":"C","text":"中國"},{"key":"D","text":"英國"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '會考', '104 年',
      'https://knowledgeatlas.cc/history/', array['west-warsaw-pact-1955', 'west-us-civil-rights-1964', 'cn-culturalrev-1966']::text[], 99,
      '原網站事件「文化大革命」自動對應。', 10, 'draft'
    ),
    (
      'ka-jh-set2-s012', 'h3c1-08', 'past',
      '附圖分別是保存在新竹和宜蘭的歷史文物，根據圖片內容判斷，這些文物與下列何者關係最密切？', '[{"key":"A","text":"清代人才選拔制度的施行"},{"key":"B","text":"鄭氏政權對於漢人文化的推廣"},{"key":"C","text":"臺灣總督府所實施的教育制度"},{"key":"D","text":"荷蘭聯合東印度公司的文教政策"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image7.png"]'::jsonb, '[]'::jsonb,
      'A', '', '會考', '108 年',
      'https://knowledgeatlas.cc/history/', array['cn-keju-605']::text[], 94,
      '原網站事件「隋唐制度發展中的科舉制度」自動對應。', 12, 'draft'
    ),
    (
      'ka-jh-set2-s018', 'h3c5-09', 'past',
      '附圖呈現清中葉以後，朝廷允許外國傳教士在華活動範圍逐漸改變的情形。造成此轉變的原因，最可能是下列何者？', '[{"key":"A","text":"清朝對外條約的簽訂"},{"key":"B","text":"耶穌會在華進行傳教"},{"key":"C","text":"清朝採取朝貢貿易體制"},{"key":"D","text":"中國經濟重心轉往內陸"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image10.png"]'::jsonb, '[]'::jsonb,
      'A', '', '會考', '105 年',
      'https://knowledgeatlas.cc/history/', array['cn-opium-1840', 'cn-arrowwar-1856']::text[], 92,
      '依題幹與答案複核：題目考查鴉片戰爭至英法聯軍後傳教範圍擴張。', 18, 'draft'
    ),
    (
      'ka-jh-set2-s022', 'h3c6-02', 'past',
      '以下是清末文人對某事件的描述：「當時在官府的默許下，群眾進入天津租界，縱火焚燒教堂、房屋，於是各街市店舖有販售洋貨者，皆用紅紙將招牌上的『洋』字糊上，以防群眾焚掠。即便是一般家庭日用之物，如洋燈、鐘錶等類，也都掩藏不敢使用。」根據上文判斷，此事件最可能是下列何者？', '[{"key":"A","text":"鴉片戰爭"},{"key":"B","text":"英法聯軍"},{"key":"C","text":"義和團事件"},{"key":"D","text":"甲午戰爭"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '107 年',
      'https://knowledgeatlas.cc/history/', array['cn-boxer-1900', 'cn-opium-1840']::text[], 99,
      '依題幹與答案複核：題目直接詢問義和團事件。', 22, 'draft'
    ),
    (
      'ka-jh-set2-s024', 'h3c5-05', 'past',
      '附圖呈現的是某地不同時期統治者的演變情況，此地最可能是下列何者？', '[{"key":"A","text":"琉球"},{"key":"B","text":"香港"},{"key":"C","text":"澳門"},{"key":"D","text":"臺灣"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image15.png"]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '107 年',
      'https://knowledgeatlas.cc/history/', array['west-wwii-1939', 'cn-opium-1840']::text[], 99,
      '原網站事件「鴉片戰爭」自動對應。', 24, 'draft'
    ),
    (
      'ka-jh-set2-s029', 'h4c5-05', 'past',
      '「在此次動亂中，民族文化飽受摧殘，孔子的墓碑被撞倒後徹底砸碎。……有位老幹部，為保護孔府門前石獅，冒險用木板將其罩住，並貼上『革命無罪，造反有理』的標語，終使石獅安然無恙。」上述最可能是在描述下列哪一事件的情況？', '[{"key":"A","text":"武昌起義"},{"key":"B","text":"文化大革命"},{"key":"C","text":"新文化運動"},{"key":"D","text":"西安事變"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '會考補考', '109 年',
      'https://knowledgeatlas.cc/history/', array['cn-culturalrev-1966', 'cn-hundred-schools']::text[], 99,
      '依題幹與答案複核：題目直接詢問文化大革命。', 29, 'draft'
    ),
    (
      'ka-jh-set2-s032', 'h3c5-08', 'past',
      '下列是某次美國外交聲明的概要，根據內容判斷，美國發表此一聲明是在哪一場戰爭之後？
我國政府希望各國在中國的商業和航運能享受平等待遇，我國人民的利益，也不得因列強在華畫分勢力範圍而受到損害，故反對列強在大清帝國領土內的獨占權利，或對土地的控制權', '[{"key":"A","text":"甲午戰爭"},{"key":"B","text":"鴉片戰爭"},{"key":"C","text":"英法聯軍"},{"key":"D","text":"八國聯軍"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '會考', '104 年',
      'https://knowledgeatlas.cc/history/', array['cn-sinojapanese-1894']::text[], 96,
      '原網站事件「甲午戰爭與馬關條約」自動對應。', 32, 'draft'
    ),
    (
      'ka-jh-set2-s033', 'h3c2-11', 'past',
      '附圖是某一時期亞洲三個國家交流的情形，根據內容判斷，此時期的交流對當時日本造成了何種影響？', '[{"key":"A","text":"採行「大化革新」，努力吸收中國文化"},{"key":"B","text":"推動「大政奉還」，天皇重新掌權執政"},{"key":"C","text":"推行「明治維新」，日本成為亞洲強國"},{"key":"D","text":"採行「鎖國政策」，只許中荷前來貿易"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image22.png"]'::jsonb, '[]'::jsonb,
      'A', '', '會考', '108 年',
      'https://knowledgeatlas.cc/history/', array['jp-taika-646', 'cn-tang-cosmopolitan']::text[], 99,
      '依題幹與答案複核：題目答案為大化革新。', 33, 'draft'
    ),
    (
      'ka-jh-set2-s035', 'h4c3-04', 'past',
      '各地所採用的時區及標準時間名稱，有時會隨著當地的政治勢力改變而有所不同。附圖為 20 世紀時，某座城市在十餘年內所屬時區及標準時間名稱的轉變。此城市最可能為下列何者？', '[{"key":"A","text":"香港"},{"key":"B","text":"臺北"},{"key":"C","text":"重慶"},{"key":"D","text":"瀋陽"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image24.png"]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '103 年',
      'https://knowledgeatlas.cc/history/', array['cn-manchuria-1931']::text[], 99,
      '原網站事件「九一八事變」自動對應。', 35, 'draft'
    ),
    (
      'ka-jh-set2-s036', 'h3c2-03', 'past',
      '中國某電視臺舉辦歷史之旅路線設計比賽，其中有一路線的行程安排如附圖所示。若要寫出呈現該路線特色的介紹詞句，可參考下列哪一歷史資料？', '[{"key":"A","text":"秦始皇耗資興建的長城"},{"key":"B","text":"張騫與玄奘走過的絲路"},{"key":"C","text":"文成公主的最後歸屬地"},{"key":"D","text":"北魏孝文帝的遷都政策"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image25.png"]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '104 年',
      'https://knowledgeatlas.cc/history/', array['cn-silkroad', 'cn-tang-cosmopolitan']::text[], 99,
      '依題幹與答案複核：題目答案為絲路。', 36, 'draft'
    ),
    (
      'ka-jh-set2-s037', 'h4c5-04', 'past',
      '附圖是參考某段期間中國人口死亡率估算值而繪製的曲線圖，圖中甲、乙二點之間死亡率的變化，最可能與下列何者有關？', '[{"key":"A","text":"人民響應抗美援朝，參與韓戰而造成傷亡慘重"},{"key":"B","text":"大躍進運動期間，政策失當所導致的嚴重饑荒"},{"key":"C","text":"文化大革命時，紅衛兵鬥爭造成眾多人口死亡"},{"key":"D","text":"六四天安門事件爆發，政府鎮壓大量抗議群眾"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image26.jpg"]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '106 年',
      'https://knowledgeatlas.cc/history/', array['cn-tiananmen-1989', 'cn-culturalrev-1966', 'korea-war-1950']::text[], 99,
      '依題幹與答案複核：題目答案為大躍進造成的饑荒。', 37, 'draft'
    ),
    (
      'ka-jh-set2-s042', 'h3c6-02', 'past',
      '1900 年，在慈禧太后默許民眾攻擊教堂及傳教士，甚至包圍北京的外國使館後，美軍第十五步兵團首次被派遣至中國保護僑民。當時美國首次派遣第十五步兵團至中國的原因，最可能是下列何者？', '[{"key":"A","text":"鴉片戰爭結束後，要求給予特權"},{"key":"B","text":"趁英法聯軍之際，脅迫開放天津"},{"key":"C","text":"與列強瓜分中國，從中獲得利益"},{"key":"D","text":"義和團事件爆發，引發八國聯軍"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '109 年',
      'https://knowledgeatlas.cc/history/', array['cn-hundred-days-1898', 'cn-boxer-1900']::text[], 99,
      '依題幹與答案複核：題目答案為義和團與八國聯軍。', 42, 'draft'
    ),
    (
      'ka-jh-set2-s043', 'h4c2-03', 'past',
      '「巴黎和會引起中國強烈的民族情緒，在部分知識分子的心中，西方角色從啟蒙者轉變為壓迫者，因此他們逐漸對維護帝國主義、資本主義的西方國家感到失望。在五四運動後，有些知識分子開始轉向世界革命理論，試圖從俄國革命家對於受壓迫民族的呼籲，以及俄國新政權宣布放棄沙皇時代在中國特權的聲明中，找到改變中國的出路。」上述內容最可能與下列何者有關？', '[{"key":"A","text":"中華民國的建立"},{"key":"B","text":"西安事變的發生"},{"key":"C","text":"中國共產黨的成立"},{"key":"D","text":"文化大革命的發動"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '114 年',
      'https://knowledgeatlas.cc/history/', array['west-russianrev-1917', 'china-mayfourth-1919']::text[], 99,
      '原網站事件「五四運動」自動對應。', 43, 'draft'
    ),
    (
      'ka-jh-set2-s045', 'h4c4-04', 'past',
      '附表為某作家的三部長篇小說內容簡介，該作家藉此構築十九至二十世紀臺灣歷史的發展過程。根據表中內容判斷，這三部小說呈現的時代先後順序，最可能是下列何者？', '[{"key":"A","text":"乙→甲→丙"},{"key":"B","text":"丙→乙→甲"},{"key":"C","text":"丙→甲→乙"},{"key":"D","text":"乙→丙→甲"}]'::jsonb, '[]'::jsonb, '[[[{"text":"著作","media":[]},{"text":"內容簡介","media":[]}],[{"text":"甲","media":[]},{"text":"刻畫多位臺灣青年在南洋戰場上被戰爭折磨至精神崩潰，甚至喪生的悲慘命運。","media":[]}],[{"text":"乙","media":[]},{"text":"敘述客家族群在臺灣中部山區生產樟腦，為保衛家園參與武裝抗日的故事。","media":[]}],[{"text":"丙","media":[]},{"text":"描繪臺灣人藉由參加文化協會、組織農民運動，抵抗殖民統治的事蹟。","media":[]}]]]'::jsonb,
      'D', '', '會考', '112 年',
      'https://knowledgeatlas.cc/history/', array['jp-pacific-1941']::text[], 99,
      '原網站事件「太平洋戰爭」自動對應。', 45, 'draft'
    ),
    (
      'ka-jh-set2-s046', 'h4c3-09', 'past',
      '「某國在十九世紀末設置一個機構，最初是顧及戰後返國的軍人，身上可能帶有病菌，因而先送往此處進行消毒及隔離，後來也在此處收容戰爭俘虜。在該國曾參與的甲午戰爭、第一次世界大戰、九一八事變，乃至於太平洋戰爭，此機構都曾發揮隔離檢疫的功能。」上述「某國」最可能是下列何者？', '[{"key":"A","text":"美國"},{"key":"B","text":"德國"},{"key":"C","text":"日本"},{"key":"D","text":"法國"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '113 年',
      'https://knowledgeatlas.cc/history/', array['west-ww1-1914', 'cn-manchuria-1931', 'jp-pacific-1941']::text[], 90,
      '依題幹與答案複核：題目以日本參與近代戰爭判斷國家。', 46, 'draft'
    ),
    (
      'ka-jh-set2-s047', 'h3c4-03', 'past',
      '附圖為2005年某博物館的宣傳海報，下列何者最可能是圖中所指「偉大的海上探險」所帶來的影響之一？', '[{"key":"A","text":"引發探險風氣，延續歐洲海外拓殖熱潮"},{"key":"B","text":"貿易管道暢通，中國白銀大量流入歐洲"},{"key":"C","text":"中國聲威遠播，奠定華人移居東南亞基礎"},{"key":"D","text":"肅清倭寇的勢力，東南沿海因此得以安定"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image28.png"]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '105 年',
      'https://knowledgeatlas.cc/history/', array['cn-zhenghe-1405']::text[], 99,
      '原網站事件「鄭和下西洋」自動對應。', 47, 'draft'
    ),
    (
      'ka-jh-set2-s051', 'h3c3-09', 'past',
      '在研究中國古代學術發展過程中，朱熹具有不可忽視的重要地位，對後世影響深遠。下列何者是他的重要成就之一？', '[{"key":"A","text":"編纂《史記》，被後世視為中國史學之父"},{"key":"B","text":"以醫術聞名，著有醫學書籍《傷寒雜病論》"},{"key":"C","text":"文學作品反映社會現實，被後世譽為「詩聖」"},{"key":"D","text":"完成《四書集注》，自元代開始被訂為科舉考試定本"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '103 年',
      'https://knowledgeatlas.cc/history/', array['cn-keju-605', 'cn-hundred-schools']::text[], 99,
      '依題幹與答案複核：題目直接考查朱熹與宋代理學。', 51, 'draft'
    ),
    (
      'ka-jh-set2-s054', 'h3c4-03', 'past',
      '以下是中國某朝代對外關係的介紹：「此王朝中期以後，先前曾遠達非洲東岸的官方遠洋航行，早已因無法負荷龐大的支出而終止；東部沿海地區遭海盜劫掠，朝廷往往束手無策。幾任皇帝雖修整傾頹的長城，依然抵擋不住北方蒙古族的侵擾。」該朝代最可能是下列何者？', '[{"key":"A","text":"南宋"},{"key":"B","text":"元代"},{"key":"C","text":"明代"},{"key":"D","text":"清代"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '107 年',
      'https://knowledgeatlas.cc/history/', array['cn-zhenghe-1405']::text[], 99,
      '原網站事件「鄭和下西洋」自動對應。', 54, 'draft'
    ),
    (
      'ka-jh-set2-s055', 'h4c1-06', 'past',
      '1900 年義和團之亂時，美軍第十五步兵團首次被派遣至中國保護僑民。清朝滅亡後，步兵團為確保美國人在華利益，長期駐守天津。袁世凱死後至北伐完成期間，中國內戰不斷，步兵團為避免動亂影響美國的利益，也曾介入其中，間接保護了天津民眾的安全。根據上文，第十五步兵團介入中國內戰，間接保護天津民眾安全，當時中國的主要政治情況為何？', '[{"key":"A","text":"立憲派與革命派爭論不休，滿清帝制搖搖欲墜"},{"key":"B","text":"地方軍事強人憑藉武力以奪取地盤，割據一方"},{"key":"C","text":"日本扶植汪精衛政權，對抗在重慶的國民政府"},{"key":"D","text":"國民黨與共產黨不斷衝突，共黨全面控制中國。\n汪精衛＝汪兆銘"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '109 年',
      'https://knowledgeatlas.cc/history/', array['cn-boxer-1900', 'cn-northern-expedition-1926']::text[], 99,
      '依題幹與答案複核：題目答案為軍閥割據。', 55, 'draft'
    ),
    (
      'ka-jh-set2-s057', 'h3c3-06', 'past',
      '以下是中國某朝代首都的簡介：「這是一座依計畫興建的城市，城中可見基督教教堂、伊斯蘭教清真寺及佛教寺廟。朝廷聘用色目人擔任財政官員，加上各地物資的集中，讓這座城市成為金融經濟中心。」上述城市最可能是指下列何者？', '[{"key":"A","text":"東漢洛陽"},{"key":"B","text":"唐代長安"},{"key":"C","text":"北宋汴京"},{"key":"D","text":"元代大都"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '106 年',
      'https://knowledgeatlas.cc/history/', array['west-islam-622', 'cn-mongol-conquest']::text[], 92,
      '原網站事件「蒙古擴張與元朝統一」自動對應。', 57, 'draft'
    ),
    (
      'ka-jh-set2-s063', 'h3c3-08', 'past',
      '附圖是某機構的性質及工作內容示意圖。據此判斷，該機構最可能為下列何者？（註：郊＝行郊）', '[{"key":"A","text":"郊"},{"key":"B","text":"公行"},{"key":"C","text":"市舶司"},{"key":"D","text":"驛站"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image36.png"]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '106 年',
      'https://knowledgeatlas.cc/history/', array['cn-maritime-song', 'cn-tang-cosmopolitan']::text[], 99,
      '依題幹與答案複核：題目答案為管理海上貿易的市舶司。', 63, 'draft'
    ),
    (
      'ka-jh-set2-s066', 'h3c5-10', 'past',
      '明清時期，蠶絲業是中國江南地區的重要產業。當時產出的生絲，主要供應國內需求，部分對外出口。下列何者最可能反映 1830 年代生絲出口的情況？', '[]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image37.png","https://knowledgeatlas.cc/history/assets/history-exams/set2-image38.png","https://knowledgeatlas.cc/history/assets/history-exams/set2-image39.png","https://knowledgeatlas.cc/history/assets/history-exams/set2-image40.png"]'::jsonb, '[]'::jsonb,
      'A', '', '會考', '112 年',
      'https://knowledgeatlas.cc/history/', array['cn-canton-1757', 'cn-opium-1840']::text[], 96,
      '依題幹與答案複核：題目考查鴉片戰爭前廣州一口通商。', 66, 'draft'
    ),
    (
      'ka-jh-set2-s067', 'h3c5-08', 'past',
      '以下是中國某座城市的介紹：「現在城內的『沂水路』全長三百多公尺。之前德國統治這座城市的時候，叫做『迪德里希斯街』；後來日本占領時，叫做『赤羽町』。雖然這是條很短的路，卻記錄了此城市的演變過程。」此一城市最可能是下列何者？', '[{"key":"A","text":"瀋陽"},{"key":"B","text":"青島"},{"key":"C","text":"南京"},{"key":"D","text":"重慶"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '109 年',
      'https://knowledgeatlas.cc/history/', array['cn-sinojapanese-1894']::text[], 96,
      '原網站事件「甲午戰爭與馬關條約」自動對應。', 67, 'draft'
    ),
    (
      'ka-jh-set2-s070', 'h4c5-05', 'past',
      '附圖是描繪中國某時期出現的情景，根據內容判斷，此圖最可能呈現下列何者？', '[{"key":"A","text":"義和團事變"},{"key":"B","text":"文化大革命"},{"key":"C","text":"新文化運動"},{"key":"D","text":"五四運動"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image43.png"]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '103 年',
      'https://knowledgeatlas.cc/history/', array['cn-culturalrev-1966']::text[], 99,
      '原網站事件「文化大革命」自動對應。', 70, 'draft'
    ),
    (
      'ka-jh-set2-s071', 'h4c3-02', 'past',
      '以下是中國天津某年慶祝元旦的相關報導：「政府要求各機關及各民眾團體，在元旦上午參加慶祝中華民國成立的紀念大會。當晚民眾提燈遍遊街市，高呼『勿忘國恥』、『抵制日貨』、『打倒貪官汙吏』、『打倒燒香化紙、磕頭拜年的惡習』等口號。各街市商號張貼標語、懸燈結綵，國民黨黨旗和國旗飄揚天際，蔚為盛況。」上述內容最可能是描繪下列何時的景象？', '[{"key":"A","text":"1861～1895 年自強運動期間"},{"key":"B","text":"1928～1937 年十年建設期間"},{"key":"C","text":"1958～1961 年農工大躍進期間"},{"key":"D","text":"1966～1976 年文化大革命期間"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '111 年',
      'https://knowledgeatlas.cc/history/', array['cn-roc-1912', 'cn-nanjing-decade', 'cn-manchuria-1931']::text[], 99,
      '依題幹與答案複核：題目答案為十年建設時期。', 71, 'draft'
    ),
    (
      'ka-jh-set2-s072', 'h3c3-06', 'past',
      '圖(一)與圖(二)分別為官方頒發的牌符及當時可通行使用的路線。根據內容判斷，這兩幅圖最適合用來說明下列何者？（註：牌符＝由官方頒發，官員可利用此證件，要求路線上的交通站提供食宿及車馬。）
圖(一)
圖(二)', '[{"key":"A","text":"兩漢時期的對外征伐"},{"key":"B","text":"大唐帝國的統治區域"},{"key":"C","text":"蒙古帝國的勢力範圍"},{"key":"D","text":"盛清時期的開疆闢土"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image44.png","https://knowledgeatlas.cc/history/assets/history-exams/set2-image45.png"]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '109 年',
      'https://knowledgeatlas.cc/history/', array['cn-mongol-conquest']::text[], 92,
      '原網站事件「蒙古擴張與元朝統一」自動對應。', 72, 'draft'
    ),
    (
      'ka-jh-set2-s074', 'h3c5-05', 'past',
      '附表是一件發生在中國境內的案件審判概況，根據內容判斷，此審判最可能出現在下列何時？', '[{"key":"A","text":"17 世紀前期"},{"key":"B","text":"18 世紀前期"},{"key":"C","text":"19 世紀後期"},{"key":"D","text":"20 世紀後期"}]'::jsonb, '[]'::jsonb, '[[[{"text":"審判概況","media":[]},{"text":"審判概況","media":[]}],[{"text":"審判地點","media":[]},{"text":"廈門的美國領事法庭","media":[]}],[{"text":"裁決者","media":[]},{"text":"美國駐廈門領事館總領事","media":[]}],[{"text":"陪審員","media":[]},{"text":"三人，包括一名美國領事館代表","media":[]}],[{"text":"被告","media":[]},{"text":"美國公民 J.H. Edward","media":[]}],[{"text":"罪名","media":[]},{"text":"於中國非法徵募及販運勞工至國外","media":[]}],[{"text":"判決","media":[]},{"text":"依美國法律判決一年監禁、罰款一千美元","media":[]}]]]'::jsonb,
      'C', '', '會考', '108 年',
      'https://knowledgeatlas.cc/history/', array['cn-opium-1840']::text[], 99,
      '原網站事件「鴉片戰爭」自動對應。', 74, 'draft'
    ),
    (
      'ka-jh-set2-s075', 'h3c1-05', 'past',
      '有位學者在演講稿中寫到：「在此以前的中國，只是一種封建的統一。直到此時，中央方面才有一個更正式的統一政府，其所轄各地方，不再是封建性的諸侯列國並存，而是緊密隸屬於中央的郡縣制行政區分了。」他所說的「此時」最可能是指下列何時？', '[{"key":"A","text":"商周"},{"key":"B","text":"秦代"},{"key":"C","text":"隋唐"},{"key":"D","text":"宋代"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '103 年',
      'https://knowledgeatlas.cc/history/', array['cn-unification-221bc', 'cn-feudal-1046']::text[], 99,
      '依題幹與答案複核：題目答案為秦代中央集權。', 75, 'draft'
    ),
    (
      'ka-jh-set2-s076', 'h4c3-02', 'past',
      '以下是一位旅行者在上海的見聞：「上海的工廠地帶可以看到轟炸的痕跡，有來到了戰場的感覺。但是如果來到租界區，興盛的商業中心立即映入眼中。在此，歐、美國家的主要銀行林立，國民政府的官方銀行—中央銀行，以及中國銀行、交通銀行等仍然繁忙地繼續營業，處理租界區內法幣的發行與交易。」此人最可能是在下列何時參訪上海？', '[{"key":"A","text":"1830 年代"},{"key":"B","text":"1890 年代"},{"key":"C","text":"1930 年代"},{"key":"D","text":"1990 年代"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '107 年',
      'https://knowledgeatlas.cc/history/', array['cn-opium-1840', 'cn-nanjing-decade']::text[], 99,
      '依題幹與答案複核：題目以 1930 年代上海與法幣為線索。', 76, 'draft'
    ),
    (
      'ka-jh-set2-s078', 'h4c4-04', 'past',
      '以下是一位西方記者對時事的報導：「過去美歐人士在中國許多城市高高在上，不僅享有領事裁判權保護，更有本國軍隊在中國駐紮。但『戰爭』改變了一切，領事裁判權被取消，美歐人士必須接受中國司法管轄，他們逍遙於中國司法之外的好日子和地位，一去不復返了。」上述「戰爭」最可能是指下列何者？', '[{"key":"A","text":"鴉片戰爭"},{"key":"B","text":"國民革命軍北伐"},{"key":"C","text":"第一次世界大戰"},{"key":"D","text":"第二次世界大戰"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '110 年',
      'https://knowledgeatlas.cc/history/', array['west-wwii-1939', 'jp-pacific-1941', 'cn-opium-1840']::text[], 99,
      '依題幹與答案複核：題目答案為第二次世界大戰。', 78, 'draft'
    ),
    (
      'ka-jh-set2-s082', 'h3c4-04', 'past',
      '以下是某政權統治臺灣期間的對外貿易策略：
一、將蔗糖、鹿皮輸往日本，再從日本購買銅、鉛和武器。
二、1670 年代，與英國達成通商協議，允許英國在安平設立商館。
三、持續與東南亞地區的呂宋（今菲律賓）、暹邏（今泰國）等地進行貿易。
上述作法主要減緩當時中國何項措施所帶來的威脅？', '[{"key":"A","text":"設立市舶司"},{"key":"B","text":"實施海禁政策"},{"key":"C","text":"頒布渡臺禁令"},{"key":"D","text":"限定廣州一口通商"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '107 年',
      'https://knowledgeatlas.cc/history/', array['cn-haijin', 'tw-zheng-policy']::text[], 99,
      '原網站事件「明代海禁」自動對應。', 82, 'draft'
    ),
    (
      'ka-jh-set2-s083', 'h3c5-10', 'past',
      '「十八世紀中期至十九世紀中期，來華貿易的西方人，只能居住在這個城的外圍附近，並與本地商人進行交易。城門警衛森嚴，西方人不得進入城內，只能在城牆外活動。」文中所述的「城」，應位於附圖何處？', '[{"key":"A","text":"甲"},{"key":"B","text":"乙"},{"key":"C","text":"丙"},{"key":"D","text":"丁"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image52.png"]'::jsonb, '[]'::jsonb,
      'D', '', '會考補考', '110 年',
      'https://knowledgeatlas.cc/history/', array['cn-canton-1757']::text[], 99,
      '依題幹與答案複核：題目直接考查廣州一口通商。', 83, 'draft'
    ),
    (
      'ka-jh-set2-s084', 'h4c1-01', 'past',
      '中國近代某一文章提到：「政府假借預備立憲的美名卻實行中央集權，假借推行新政卻搜刮民間錢財，對外則割讓土地，並出賣採礦權與鐵路經營權。人民反對政策，可能會被處死；如果人民自己出錢出力興修鐵路，又會被官方沒收。政府應該要保護人民，結果人民反而受到政府的傷害，如此不顧人民生命、財產的政府，誰還能忍受呢！」上文的主要訴求最可能是下列何者？', '[{"key":"A","text":"因對外戰爭受到挫敗，提倡學習西方的軍事及工業技術"},{"key":"B","text":"推動制度層面的改革，以解決自強運動改革不彰的問題"},{"key":"C","text":"對改革結果感到失望，體認到革命也是救國的途徑之一"},{"key":"D","text":"主張全面改革思想文化，提倡西方科學精神與白話文學"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '111 年',
      'https://knowledgeatlas.cc/history/', array['cn-newculture-1915', 'cn-selfstrength-1861', 'cn-hundred-days-1898']::text[], 96,
      '依題幹與答案複核：題目考查清末改革失敗與革命契機。', 84, 'draft'
    ),
    (
      'ka-jh-set2-s086', 'h3c2-07', 'past',
      '「這個朝代開國以來一向尊崇道教，同時對於不同宗教也抱持包容的態度，天竺（今印度）、新羅、日本等地的佛教僧侶都會來到首都長安，進行宗教交流。但後來朝廷態度有所轉變，開始強化對其他宗教的管制，毀去數以千計的佛教寺院，並沒收寺院田產，要求僧尼還俗，連祆教及在此朝代傳入的摩尼教等宗教，也被認為是邪教，而被禁止。」根據內容判斷，這最可能在描述下列哪一朝代曾經出現的情況？', '[{"key":"A","text":"漢朝"},{"key":"B","text":"唐朝"},{"key":"C","text":"元朝"},{"key":"D","text":"清朝"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '107 年',
      'https://knowledgeatlas.cc/history/', array['cn-tang-cosmopolitan']::text[], 99,
      '原網站事件「唐代多元文化交流」自動對應。', 86, 'draft'
    ),
    (
      'ka-jh-set2-s090', 'h4c5-07', 'past',
      '某中共領導人接見日本國會議員時提到：「戰後日本很快就發達起來，這經驗很值得中國學習。當然，別人的經驗照搬也不行，中國有中國的條件，日本有日本的條件。我們不但要引進發達國家的資金和技術，充分利用各國的好經驗，並且要把這種經驗與中國的實際情況結合起來。」上述談話最可能與下列何者有關？', '[{"key":"A","text":"發起文化大革命，破除四舊"},{"key":"B","text":"推動農工大躍進，超英趕美"},{"key":"C","text":"沒收地主土地，分配給貧農"},{"key":"D","text":"實施改革開放，設經濟特區"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '112 年',
      'https://knowledgeatlas.cc/history/', array['cn-reform-1978']::text[], 99,
      '原網站事件「改革開放」自動對應。', 90, 'draft'
    ),
    (
      'ka-jh-set2-s093', 'h3c1-05', 'past',
      '附圖甲、乙分別代表中國歷史上兩種重要的政治體制。若要用圖中甲、乙呈現周代至秦代政治體制的變化順序，下列何者最為適切？', '[{"key":"A","text":"甲→乙"},{"key":"B","text":"乙→甲"},{"key":"C","text":"甲→乙→甲"},{"key":"D","text":"乙→甲→乙"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image55.png"]'::jsonb, '[]'::jsonb,
      'A', '', '會考陸考', '112 年',
      'https://knowledgeatlas.cc/history/', array['cn-feudal-1046', 'cn-unification-221bc']::text[], 99,
      '依題幹與答案複核：題目考查西周封建至秦代郡縣的變化。', 93, 'draft'
    ),
    (
      'ka-jh-set2-s095', 'h3c5-09', 'past',
      '附圖的四張卡片分別代表清朝曾對臺灣採取的統治措施，若依這些措施最早在臺施行的時間先後順序排列，下列何者正確？', '[{"key":"A","text":"甲→丁→乙→丙"},{"key":"B","text":"乙→甲→丙→丁"},{"key":"C","text":"丙→乙→丁→甲"},{"key":"D","text":"丁→丙→甲→乙"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image56.png"]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '108 年',
      'https://knowledgeatlas.cc/history/', array['tw-open-1858', 'cn-arrowwar-1856', 'tw-province-1885']::text[], 99,
      '原網站事件「英法聯軍」自動對應。', 95, 'draft'
    ),
    (
      'ka-jh-set2-s098', 'h3c5-05', 'past',
      '附圖是某一港口附近的各國商館平面示意圖，根據圖中內容判斷，此一港口最可能是下列何者？', '[{"key":"A","text":"十七世紀後期的長崎"},{"key":"B","text":"十八世紀前期的香港"},{"key":"C","text":"十八世紀後期的安平"},{"key":"D","text":"十九世紀前期的廣州"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image58.png"]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '109 年',
      'https://knowledgeatlas.cc/history/', array['cn-opium-1840']::text[], 99,
      '原網站事件「鴉片戰爭」自動對應。', 98, 'draft'
    ),
    (
      'ka-jh-set2-s101', 'h3c3-06', 'past',
      '「此一朝代版圖遼闊，境內民族複雜，蒙古、女真、契丹、高麗、漢族等族雜居；加上先前的軍事行動，曾經遠達西亞、歐洲，帶回突厥、波斯、斡羅思（俄羅斯）及東歐各族人士。上述情況使得此朝代族群繁多，遠遠超過其他時期，在中國史上可謂獨一無二。」此一朝代最可能是下列何者？', '[{"key":"A","text":"漢朝"},{"key":"B","text":"唐朝"},{"key":"C","text":"元朝"},{"key":"D","text":"清朝"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '105 年',
      'https://knowledgeatlas.cc/history/', array['cn-mongol-conquest']::text[], 92,
      '原網站事件「蒙古擴張與元朝統一」自動對應。', 101, 'draft'
    ),
    (
      'ka-jh-set2-s113', 'h3c6-02', 'past',
      '附圖為一首歌曲部分歌詞的翻譯，其內容聚焦於中國歷史上某一事件。歌詞中「在東方的血腥戰爭」，最可能是指下列何者？', '[{"key":"A","text":"蒙古大軍南下滅宋，成功入主中國"},{"key":"B","text":"英國為鴉片貿易問題出兵攻打中國"},{"key":"C","text":"八個國家組成聯軍向中國發動攻擊"},{"key":"D","text":"國民政府誓師北伐，終結軍閥割據"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image70.png","https://knowledgeatlas.cc/history/assets/history-exams/set2-image71.png"]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '113 年',
      'https://knowledgeatlas.cc/history/', array['cn-hundred-days-1898', 'cn-boxer-1900']::text[], 99,
      '依題幹與答案複核：題目答案為八國聯軍。', 113, 'draft'
    ),
    (
      'ka-jh-set2-s122', 'h3c2-07', 'past',
      '附圖是玉潔參觀「歷代中國婦女生活文物展」時，在某朝代的展示區內所看到的文物簡介。依內容判斷，此朝代最可能是下列何者？', '[{"key":"A","text":"漢代"},{"key":"B","text":"唐代"},{"key":"C","text":"宋代"},{"key":"D","text":"明代"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image78.png"]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '109 年',
      'https://knowledgeatlas.cc/history/', array['cn-tang-cosmopolitan']::text[], 99,
      '原網站事件「唐代多元文化交流」自動對應。', 122, 'draft'
    ),
    (
      'ka-jh-set2-s130', 'h3c6-03', 'past',
      '「當日本這個島國一戰成名，躍升為世界強國之際，中國有志之士深感危機重重，各地紛紛組織請願代表團，向中央呈遞請願書，要求儘快召開國會、設置內閣，方得以救亡圖存。雖請願訴求遭到拒絕，但全國各地仍以各種抗爭行動，持續聲援，希望促使政府實踐改革。」上述情況與下列何者有關？', '[{"key":"A","text":"唐代大化革新"},{"key":"B","text":"明代海禁政策"},{"key":"C","text":"清末立憲運動"},{"key":"D","text":"臺灣議會設置請願運動"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考陸考', '112 年',
      'https://knowledgeatlas.cc/history/', array['jp-russo-1904', 'west-ww1-1914', 'cn-lateqing-reform']::text[], 99,
      '依題幹與答案複核：題目答案為清末立憲運動。', 130, 'draft'
    ),
    (
      'ka-jh-set2-s132', 'h4c3-08', 'past',
      '「因為戰爭的緣故，北平（今北京）淪陷，清華大學、北京大學以及南開大學共同組成臨時大學，配合政府應戰策略，先南撤到湖南長沙繼續開課。但敵軍的飛機頻繁轟炸，學生大部分時間都在教室和防空洞間來回跑著。隨著戰事吃緊，政府遷往四川，學校也遷徙到雲南。」文中的戰爭最可能是下列何者？', '[{"key":"A","text":"八國聯軍"},{"key":"B","text":"武昌起義"},{"key":"C","text":"八年抗戰"},{"key":"D","text":"國民政府北伐"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考補考', '110 年',
      'https://knowledgeatlas.cc/history/', array['cn-warjapan-1937']::text[], 96,
      '原網站事件「中日戰爭全面爆發」自動對應。', 132, 'draft'
    ),
    (
      'ka-jh-set2-s137', 'h3c1-05', 'past',
      '「君王集軍政大權於一身，其下有輔助推動政務的宰相，以及漸趨系統化和專業化的文武官員，地方上的郡縣長官也由君王直接任命。這些大小官員大部分不再是憑藉血緣世襲的封建貴族，而是平民出身的才學之士。」上文最能說明中國歷史上何種情況的發展？', '[{"key":"A","text":"世族社會的出現"},{"key":"B","text":"地方勢力的割據"},{"key":"C","text":"君主立憲的實施"},{"key":"D","text":"中央集權的形成"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '106 年',
      'https://knowledgeatlas.cc/history/', array['cn-unification-221bc']::text[], 99,
      '原網站事件「秦統一與中央集權」自動對應。', 137, 'draft'
    ),
    (
      'ka-jh-set2-s138', 'h3c2-06', 'past',
      '「中國史上，某位皇帝考量原根據地的農業生產落後，且北方外族威脅漸弱，為有效擴張勢力，因此將都城向南遷徙到漢文化的重鎮。遷都後，因貴族與大臣反彈，甚至起而叛亂，皇帝剷除反對勢力後，更加大力推行漢化。」上文所述最可能是下列何事？', '[{"key":"A","text":"元朝忽必烈建都大都"},{"key":"B","text":"秦始皇以咸陽為首都"},{"key":"C","text":"東周時平王東遷雒邑"},{"key":"D","text":"北魏孝文帝定都洛陽"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '105 年',
      'https://knowledgeatlas.cc/history/', array['cn-northern-wei-reform']::text[], 99,
      '原網站事件「北魏孝文帝改革」自動對應。', 138, 'draft'
    ),
    (
      'ka-jh-set2-s142', 'h3c2-03', 'past',
      '附圖呈現某一時期中外交流概況，下列何者符合該時期的往來情形？', '[{"key":"A","text":"雙方以紙幣作為交易的媒介"},{"key":"B","text":"伊斯蘭教隨著商人傳入中國"},{"key":"C","text":"西方出口玉米、番薯等作物"},{"key":"D","text":"中國以絲綢為主要輸出商品"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image89.png"]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '107 年',
      'https://knowledgeatlas.cc/history/', array['cn-silkroad', 'cn-tang-cosmopolitan']::text[], 99,
      '依題幹與答案複核：題目考查絲路貿易。', 142, 'draft'
    ),
    (
      'ka-jh-set2-s144', 'h4c3-02', 'past',
      '在某本以近現代中國為背景的小說中寫到︰「最近，國家開始實施新政策，由政府指定中央、交通、中國這幾家銀行發行法幣。我想，此政策若真能好好實行，改善過去幣制混亂的情況，買賣交易就比較好做了。」這段話所呈現的最可能是中國處於下列何種局勢下的情況？', '[{"key":"A","text":"戊戍變法期間，朝廷推動經濟改革"},{"key":"B","text":"八國聯軍結束，朝廷陸續推行新政"},{"key":"C","text":"北伐統一完成，政府致力建設發展"},{"key":"D","text":"八年抗戰後期，政府籌措資金抗日"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '105 年',
      'https://knowledgeatlas.cc/history/', array['cn-nanjing-decade', 'cn-northern-expedition-1926']::text[], 99,
      '依題幹與答案複核：題目考查十年建設與法幣政策。', 144, 'draft'
    ),
    (
      'ka-jh-set2-s146', 'h4c4-07', 'past',
      '臺灣有一位熟知各類蚊子及其傳播疾病的專家，人稱「蚊子博士」。他 15 歲時便開始參與登革熱疫情的訪查，雖然因此染病，卻不減他對蚊蟲研究的熱情。國民政府接收臺灣初期，因政經情勢的變化，加上語言隔閡、文化差異，使得社會動盪不安，他只好暫停學業與研究工作。上文所述社會動盪不安的年代，主要是指下列何者？', '[{"key":"A","text":"1910 年代"},{"key":"B","text":"1930 年代"},{"key":"C","text":"1940 年代"},{"key":"D","text":"1960 年代"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '104 年',
      'https://knowledgeatlas.cc/history/', array['tw-takeover-1945', 'china-civilwar-1946']::text[], 96,
      '原網站事件「國共內戰與兩岸分治」自動對應。', 146, 'draft'
    ),
    (
      'ka-jh-set2-s148', 'h3c5-05', 'past',
      '附圖呈現某時期中國官方在面對外國人犯罪時處理方式的轉變，此一轉變與下列何者關係最為密切？', '[{"key":"A","text":"總理衙門的設置"},{"key":"B","text":"中華民國的建立"},{"key":"C","text":"海禁政策的實施"},{"key":"D","text":"晚清對外條約的簽訂"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image92.png","https://knowledgeatlas.cc/history/assets/history-exams/set2-image93.png"]'::jsonb, '[]'::jsonb,
      'D', '', '會考陸考', '112 年',
      'https://knowledgeatlas.cc/history/', array['cn-opium-1840']::text[], 99,
      '原網站事件「鴉片戰爭」自動對應。', 148, 'draft'
    ),
    (
      'ka-jh-set2-s149', 'h3c6-02', 'past',
      '小民蒐集中國近代某一歷史事件的四份相關資料，如附表所示。表中的「資料一」最可能是下列何者？', '[{"key":"A","text":"太平軍正向北方發展，勢力從南京向首都北京地區蔓延"},{"key":"B","text":"大學生罷課、結隊在全城遊行，並聚集至親日官員住宅抗議"},{"key":"C","text":"義和團燒毀天主教堂、美國傳教團體的房舍，以及海關外國雇員的住所"},{"key":"D","text":"武昌已經宣布成立共和政權，革命軍隊準備和來自北方的清朝軍隊作戰"}]'::jsonb, '[]'::jsonb, '[[[{"text":"資料一","media":[]},{"text":"？","media":[]}],[{"text":"資料二","media":[]},{"text":"英國人派來攻打中國的上萬名士兵，在北京天壇紮營。他們的馬，蹂躪著一切。","media":[]}],[{"text":"資料三","media":[]},{"text":"俄國人洗劫北京頤和園的行動已經完成，所有珍貴物品都已經包裝好並貼上標籤。","media":[]}],[{"text":"資料四","media":[]},{"text":"法、德兩國把北京天文臺的珍貴儀器據為己有，儀器將被送往巴黎和柏林。","media":[]}]]]'::jsonb,
      'C', '', '會考', '110 年',
      'https://knowledgeatlas.cc/history/', array['cn-boxer-1900', 'cn-hundred-days-1898']::text[], 99,
      '依題幹與答案複核：題目答案為義和團事件。', 149, 'draft'
    ),
    (
      'ka-jh-set2-s151', 'h4c5-04', 'past',
      '有位中國老農夫回憶：「當時煉鋼要超英趕美，因此人人將鍋、鏟全丟進煉鐵爐燒煉。因為上級交代蓋一條用來運鋼的道路，所以只好將鄭和墓塚的石頭拿去墊路基，但我們一直沒有煉出夠多的數量，讓卡車來載運。」上述情況最可能與下列何者有關？', '[{"key":"A","text":"大躍進"},{"key":"B","text":"土地改革"},{"key":"C","text":"文化大革命"},{"key":"D","text":"改革開放"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '會考', '108 年',
      'https://knowledgeatlas.cc/history/', array['cn-greatleap-1958', 'cn-zhenghe-1405']::text[], 99,
      '依題幹與答案複核：題目答案為大躍進。', 151, 'draft'
    ),
    (
      'ka-jh-set2-s152', 'h4c4-04', 'past',
      '附圖中甲、乙、丙三張照片，分別與某戰爭中的三個重要事件有關，若依這些事件發生的時間先後順序排列，下列何者正確？
甲、長崎原子彈爆炸遺跡
乙、珍珠港事件紀念
丙、諾曼第登陸陣亡將士紀念碑', '[{"key":"A","text":"乙甲丙"},{"key":"B","text":"乙丙甲"},{"key":"C","text":"丙甲乙"},{"key":"D","text":"丙乙甲"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image95.png","https://knowledgeatlas.cc/history/assets/history-exams/set2-image96.png","https://knowledgeatlas.cc/history/assets/history-exams/set2-image97.png"]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '104 年',
      'https://knowledgeatlas.cc/history/', array['jp-pacific-1941', 'west-wwii-1939']::text[], 99,
      '原網站事件「太平洋戰爭」自動對應。', 152, 'draft'
    ),
    (
      'ka-jh-set2-s155', 'h4c3-08', 'past',
      '附圖是某報紙報導的部分內容，標題中的「？」最適合填入下列何者？', '[{"key":"A","text":"辛亥革命"},{"key":"B","text":"北伐統一"},{"key":"C","text":"八年抗戰"},{"key":"D","text":"抗美援朝"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image99.png","https://knowledgeatlas.cc/history/assets/history-exams/set2-image100.png"]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '114 年',
      'https://knowledgeatlas.cc/history/', array['cn-warjapan-1937', 'jp-pacific-1941']::text[], 99,
      '依題幹與答案複核：題目答案為八年抗戰。', 155, 'draft'
    ),
    (
      'ka-jh-set2-s164', 'h3c5-09', 'past',
      '十七世紀時，在臺灣的歐洲傳教士，以羅馬字拼寫原住民語的方式傳教，但隨著政權轉變，傳教事業逐漸式微。後來，因為某一「史事」的發生，傳教士獲得官方允許，又開始在臺灣傳教，也使用羅馬字拼寫本地語言，編寫傳教文書。此「史事」最可能是下列何者？', '[{"key":"A","text":"中英鴉片戰爭"},{"key":"B","text":"臺灣開港通商"},{"key":"C","text":"法國攻占臺灣"},{"key":"D","text":"清廷將臺灣納入版圖"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '會考補考', '110 年',
      'https://knowledgeatlas.cc/history/', array['tw-open-1858', 'cn-arrowwar-1856']::text[], 99,
      '原網站事件「英法聯軍」自動對應。', 164, 'draft'
    ),
    (
      'ka-jh-set2-s169', 'h3c1-05', 'past',
      '小惠在筆記上畫了一幅關係圖，其中「？」是筆記的主題，如附圖所示。根據內容判斷，此主題應是下列何者？', '[{"key":"A","text":"朝貢貿易的推動"},{"key":"B","text":"中央集權的奠基"},{"key":"C","text":"科舉制度的建立"},{"key":"D","text":"九品官人之法的實施"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image104.png"]'::jsonb, '[]'::jsonb,
      'B', '', '會考補考', '111 年',
      'https://knowledgeatlas.cc/history/', array['cn-unification-221bc']::text[], 99,
      '原網站事件「秦統一與中央集權」自動對應。', 169, 'draft'
    ),
    (
      'ka-jh-set2-s177', 'h3c2-07', 'past',
      '附表介紹中國某一朝代宗教信仰的概況，此一朝代最可能是下列何者？', '[{"key":"A","text":"漢朝"},{"key":"B","text":"唐朝"},{"key":"C","text":"元朝"},{"key":"D","text":"清朝"}]'::jsonb, '[]'::jsonb, '[[[{"text":"宗教信仰","media":[]},{"text":"概述","media":[]}],[{"text":"道教","media":[]},{"text":"受到皇帝支持，蓬勃發展，信仰者眾。","media":[]}],[{"text":"佛教","media":[]},{"text":"積極翻譯佛經，並有禪宗等數個宗派，促成佛教中國化。","media":[]}],[{"text":"景教","media":[]},{"text":"在長安設有寺院，並有「大秦景教流行中國碑」傳世。","media":[]}],[{"text":"摩尼教","media":[]},{"text":"此時期傳入，主要信仰者為西域商人。","media":[]}],[{"text":"伊斯蘭教","media":[]},{"text":"此時期傳入，主要信仰者為居住在廣州等地的阿拉伯商人。","media":[]}]]]'::jsonb,
      'B', '', '會考補考', '110 年',
      'https://knowledgeatlas.cc/history/', array['cn-tang-cosmopolitan', 'west-islam-622']::text[], 99,
      '原網站事件「唐代多元文化交流」自動對應。', 177, 'draft'
    ),
    (
      'ka-jh-set2-s183', 'h3c1-02', 'past',
      '西元前十ㄧ世紀周人滅商後，其勢力持續向東方擴展，由於周管轄的土地與人口在短時間內急速增加，為了天下的長治久安，因此周朝的統治者，設計出一套有效的政治制度管理各地。上述政治制度的內容，最可能是下列何者？', '[{"key":"A","text":"在領土內設置郡、縣，官員由國君直接任免"},{"key":"B","text":"實施科舉制度，促進社會各階層人才的流動"},{"key":"C","text":"將百姓編入戶籍，並以法律規範人民的義務"},{"key":"D","text":"依據貴族的身分等級，授予土地與冊封爵位"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '112 年',
      'https://knowledgeatlas.cc/history/', array['cn-feudal-1046']::text[], 99,
      '原網站事件「西周封建制度」自動對應。', 183, 'draft'
    ),
    (
      'ka-jh-set2-s188', 'h4c5-04', 'past',
      '附圖是某一中國現代史攝影專輯的部分內容，圖中所呈現的景象，最可能與下列何者有關？', '[{"key":"A","text":"大躍進"},{"key":"B","text":"土地改革"},{"key":"C","text":"改革開放"},{"key":"D","text":"文化大革命"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image115.png"]'::jsonb, '[]'::jsonb,
      'A', '', '會考', '110 年',
      'https://knowledgeatlas.cc/history/', array['cn-greatleap-1958']::text[], 99,
      '原網站事件「大躍進與人民公社」自動對應。', 188, 'draft'
    ),
    (
      'ka-jh-set2-s194', 'h3c2-07', 'past',
      '附圖描繪中國某一朝代的官員正在接待來訪使節的情況，根據圖片內容判斷，此朝代最可能是下列何者？', '[{"key":"A","text":"周朝"},{"key":"B","text":"漢朝"},{"key":"C","text":"唐朝"},{"key":"D","text":"清朝"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image123.png"]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '104 年',
      'https://knowledgeatlas.cc/history/', array['cn-tang-cosmopolitan']::text[], 99,
      '原網站事件「唐代多元文化交流」自動對應。', 194, 'draft'
    ),
    (
      'ka-jh-set2-s196', 'h4c3-07', 'past',
      '「關於我的『政治主張』，因為和蔣委員長在意見上的衝突，已經沒有和解的跡象。我考慮了三種方法來解決此事，第一是辭職、第二是勸諫、第三是兵諫。第一個方法因為我的國難家仇，和東北軍部下們的反對而不可行。最近我試了第二個方法，但導致蔣委員長極端憤怒。因此我決定採取第三個方法，以武力拘禁蔣委員長。」上述「政治主張」最可能為下列何者？', '[{"key":"A","text":"立即停止內戰，聯合各黨派抗日"},{"key":"B","text":"反對洪憲帝制，起兵討伐袁世凱"},{"key":"C","text":"終結軍閥混戰，完成中國的統一"},{"key":"D","text":"攘外必先安內，全力剿滅共產黨"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image126.png"]'::jsonb, '[]'::jsonb,
      'A', '', '會考', '112 年',
      'https://knowledgeatlas.cc/history/', array['cn-xian-1936']::text[], 99,
      '原網站事件「西安事變」自動對應。', 196, 'draft'
    ),
    (
      'ka-jh-set2-s201', 'h3c2-07', 'past',
      '附圖呈現某一時期東亞部分國家的都城規畫，以及交流路線示意圖。根據內容判斷，圖中的路線最可能是下列何者？', '[{"key":"A","text":"鄭成功船隊在東亞的貿易路線"},{"key":"B","text":"耶穌會教士在東亞的傳教路線"},{"key":"C","text":"甲午戰爭時日本進攻中國的路線"},{"key":"D","text":"唐朝時日本使者前往中國的路線"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image128.png"]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '110 年',
      'https://knowledgeatlas.cc/history/', array['cn-tang-cosmopolitan', 'jp-kentoshi-630']::text[], 99,
      '原網站事件「唐代多元文化交流」自動對應。', 201, 'draft'
    ),
    (
      'ka-jh-set2-s203', 'h4c4-04', 'past',
      '附圖是日本繪製的第二次世界大戰形勢圖，三種圖例代表與日本三種不同關係。從圖中標示的圖例，可得知這是 1941 年底太平洋戰爭爆發後的世界形勢，最主要的判斷依據應為下列何者？', '[{"key":"A","text":"英國和德國使用不同圖例"},{"key":"B","text":"英國和美國使用相同圖例"},{"key":"C","text":"朝鮮和日本使用相同圖例"},{"key":"D","text":"德國和日本使用相同圖例"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image130.png"]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '111 年',
      'https://knowledgeatlas.cc/history/', array['west-wwii-1939', 'jp-pacific-1941']::text[], 99,
      '原網站事件「太平洋戰爭」自動對應。', 203, 'draft'
    ),
    (
      'ka-jh-set2-s205', 'h4c4-05', 'past',
      '附圖是臺灣史上的一份官方文件，此文件發布的時代背景最可能是下列何者？', '[{"key":"A","text":"《馬關條約》簽訂，日本統治臺灣"},{"key":"B","text":"日本戰敗，中華民國政府接收臺灣"},{"key":"C","text":"國共內戰失利，中華民國政府遷臺"},{"key":"D","text":"民國六十年，中華民國退出聯合國"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image131.png"]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '109 年',
      'https://knowledgeatlas.cc/history/', array['jp-surrender-1945', 'tw-shimonoseki-1895', 'cn-warjapan-1937']::text[], 99,
      '依題幹與答案複核：題目考查日本投降與中華民國接收臺灣。', 205, 'draft'
    ),
    (
      'ka-jh-set2-s210', 'h3c3-06', 'past',
      '一份歷史文告寫道：「自宋朝覆亡，北方外族入主中原，百年不到，天下大亂。我本是平民，被眾人推舉，率軍攻占金陵（今南京），再北上驅逐胡虜。色目等雖為異族，但若衷心歸順，仍是中華子民。」以上敘述與下列哪一史事關係最密切？', '[{"key":"A","text":"朱元璋起兵反元"},{"key":"B","text":"鄭成功反清復明"},{"key":"C","text":"秦始皇統一中國"},{"key":"D","text":"唐太宗滅東突厥"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '會考', '104 年',
      'https://knowledgeatlas.cc/history/', array['cn-mongol-conquest']::text[], 92,
      '原網站事件「蒙古擴張與元朝統一」自動對應。', 210, 'draft'
    ),
    (
      'ka-jh-set2-s212', 'h3c5-06', 'past',
      '附表是中國歷史上某一官方教育機構的課程概況，這些因應國家需要的課程，與下列何者關係密切？', '[{"key":"A","text":"自強運動"},{"key":"B","text":"蒙古西征"},{"key":"C","text":"義和團事變爆發"},{"key":"D","text":"耶穌會教士來華"}]'::jsonb, '[]'::jsonb, '[[[{"text":"課別","media":[]},{"text":"內容","media":[]}],[{"text":"公共課","media":[]},{"text":"法文、英文、算術、幾何","media":[]}],[{"text":"專業基礎課","media":[]},{"text":"三角、解析幾何、微積分、物理、機械學等","media":[]}],[{"text":"專業課","media":[]},{"text":"蒸汽機的製造與操作、艦體製造","media":[]}],[{"text":"實踐課","media":[]},{"text":"熟悉機械工具、實習蒸汽機製造和船體建造","media":[]}]]]'::jsonb,
      'A', '', '會考補考', '109 年',
      'https://knowledgeatlas.cc/history/', array['cn-selfstrength-1861']::text[], 99,
      '原網站事件「自強運動」自動對應。', 212, 'draft'
    ),
    (
      'ka-jh-set2-s214', 'h4c3-04', 'past',
      '附圖是一幅宣傳海報，此宣傳海報最早可能在下列何時何地傳布？', '[{"key":"A","text":"1919～1930 年的臺北"},{"key":"B","text":"1949～1960 年的臺北"},{"key":"C","text":"1916～1928 年的瀋陽"},{"key":"D","text":"1932～1945 年的瀋陽"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image134.png"]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '106 年',
      'https://knowledgeatlas.cc/history/', array['cn-manchuria-1931']::text[], 99,
      '原網站事件「九一八事變」自動對應。', 214, 'draft'
    ),
    (
      'ka-jh-set2-s219', 'h4c4-04', 'past',
      '「某年，美國空軍飛臨敵區臺灣進行偵查空照，並於年底開始對臺灣各地的市街、車站、糖廠進行轟炸，臺灣西部縱貫公路與鐵路受創嚴重。」上述情況的發生，與下列何者關係最密切？', '[{"key":"A","text":"韓戰"},{"key":"B","text":"盧溝橋事變"},{"key":"C","text":"珍珠港事件"},{"key":"D","text":"美國與中華民國斷交"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '103 年',
      'https://knowledgeatlas.cc/history/', array['jp-pacific-1941']::text[], 99,
      '原網站事件「太平洋戰爭」自動對應。', 219, 'draft'
    ),
    (
      'ka-jh-set2-s221', 'h3c4-05', 'past',
      '附圖是日本對於來到長崎貿易的某國船隻數量統計圖，根據圖中資訊判斷，此國最可能是下列何者？', '[{"key":"A","text":"英國"},{"key":"B","text":"中國"},{"key":"C","text":"葡萄牙"},{"key":"D","text":"西班牙"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image138.png"]'::jsonb, '[]'::jsonb,
      'B', '', '會考補考', '110 年',
      'https://knowledgeatlas.cc/history/', array['jp-sakoku-1633']::text[], 90,
      '原網站事件「德川幕府與鎖國政策」自動對應。', 221, 'draft'
    ),
    (
      'ka-jh-set2-s222', 'h3c5-05', 'past',
      '二十世紀初期，一位名叫林謀昌的臺灣人，在福建因為商業訴訟糾紛遭到清朝官吏逮捕、監禁。此事引起日本政府的抗議，並依據與清朝簽訂的條約規定：「日本臣民在中國境內的訴訟，皆由日本派官吏調查、審理，與中國官員無關。」要求釋放林謀昌。上述日本政府援引的條約內容，顯示日本擁有下列哪一特殊待遇？', '[{"key":"A","text":"協定關稅"},{"key":"B","text":"設立租界"},{"key":"C","text":"片面最惠國"},{"key":"D","text":"領事裁判權"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '會考補考', '110 年',
      'https://knowledgeatlas.cc/history/', array['cn-opium-1840']::text[], 99,
      '原網站事件「鴉片戰爭」自動對應。', 222, 'draft'
    ),
    (
      'ka-jh-set2-s227', 'h3c2-07', 'past',
      '一位官員對於日本應如何有效統治臺灣，有以下的見解：「臺灣人偏愛黃金、儀式排場、華麗的房舍與花園，一如唐代詩文中有這樣的描述：『若沒有看到雄偉的宮殿，怎能感受到天子的尊貴。』想要有效統治臺灣人，建造宏偉的官衙，定能達到收服人心的效果。」下列何項建築的興建，可被視為日本政府對於上述想法的具體實踐？', '[{"key":"A","text":"臺灣總督府"},{"key":"B","text":"泉郊會館"},{"key":"C","text":"熱蘭遮城"},{"key":"D","text":"臺南孔（子）廟"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'A', '', '會考陸考', '112 年',
      'https://knowledgeatlas.cc/history/', array['tw-63law-1896', 'cn-tang-cosmopolitan']::text[], 99,
      '原網站事件「唐代多元文化交流」自動對應。', 227, 'draft'
    ),
    (
      'ka-jh-set2-s229', 'h4c6-02', 'past',
      '附圖是一幅歷史照片與說明，圖說人物曾兩度被俘。依據說明，此人最可能先後被下列何者所俘？', '[{"key":"A","text":"日本、美國"},{"key":"B","text":"日本、中國國民黨"},{"key":"C","text":"中國共產黨、美國"},{"key":"D","text":"中國共產黨、北韓"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image145.jpg"]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '105 年',
      'https://knowledgeatlas.cc/history/', array['china-civilwar-1946', 'korea-war-1950', 'tw-us-aid-1951']::text[], 99,
      '依題幹與答案複核：題目考查國共內戰與韓戰的先後。', 229, 'draft'
    ),
    (
      'ka-jh-set2-s234', 'h3c5-05', 'past',
      '「自來水管在租界內埋設，沿街每十數步設置四尺高的吸水鐵桶，鐵桶下面與水管連接，使用時將鐵桶上的機關轉開，水就會激射而下。自來水管理單位有兩處，法國租界的管理處設在萬安里，英國租界的管理處就設在儲水的水塔旁邊。管線外需要用水的居民也可以請水夫外送，不論遠近，每擔水都收十文錢。」上述最可能是描寫下列何者的情形？', '[{"key":"A","text":"十八世紀初的北京"},{"key":"B","text":"十八世紀末的廣州"},{"key":"C","text":"十九世紀初的廈門"},{"key":"D","text":"十九世紀末的上海"}]'::jsonb, '["https://knowledgeatlas.cc/history/assets/history-exams/set2-image151.png"]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '113 年',
      'https://knowledgeatlas.cc/history/', array['cn-opium-1840']::text[], 99,
      '原網站事件「鴉片戰爭」自動對應。', 234, 'draft'
    ),
    (
      'ka-jh-set2-g01-q1', 'h3c5-09', 'past',
      '閱讀下列選文，回答下列各題：
1855 年，美商威廉士洋行的商船航行至臺灣府安平外海，並派人上岸詢問是否能在當地貿易。經過安排，船長和臺灣道裕鐸在打狗會面，裕鐸在會談中告知船長，外國商船如果直接在安平停泊，並不符合規定，臺灣道將受到朝廷處罰，但裕鐸和打狗地方官員可以私下允許外國商船，停靠遠離政治核心的打狗進行貿易。
然而，實際上官員後來往往放任外國商船停靠安平，未能嚴格執行禁令。過了數年，新任的臺灣道孔昭慈於 1859 年，又要求外國商船「不准像之前一樣在安平附近起卸貨物」。有位英國商人分析：「這並非臺灣道刻意禁止外商在臺灣府貿易，而是因為府城當地泉州人組成的商人團體，跑去向福建巡撫告狀，指控外國商船收購物產，造成物價上漲，影響了本地商人的生意。」
臺灣道：臺灣建省前，在臺灣的最高文官。

根據上文中裕鐸與洋行的會談結果，當時臺灣對外貿易的情況，最可能是下列何者？', '[{"key":"A","text":"當時臺灣尚未對外開港，裕鐸嚴禁洋商在臺貿易"},{"key":"B","text":"當時臺灣尚未對外開港，實際上洋商已來臺貿易"},{"key":"C","text":"當時臺灣已經對外開港，洋商可在臺灣各港口貿易"},{"key":"D","text":"當時臺灣已經對外開港，裕鐸仍阻撓洋商在臺貿易"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '111 年',
      'https://knowledgeatlas.cc/history/', array['tw-province-1885', 'cn-arrowwar-1856']::text[], 99,
      '原網站事件「英法聯軍」自動對應。', 1, 'draft'
    ),
    (
      'ka-jh-set2-g01-q2', 'h3c5-09', 'past',
      '閱讀下列選文，回答下列各題：
1855 年，美商威廉士洋行的商船航行至臺灣府安平外海，並派人上岸詢問是否能在當地貿易。經過安排，船長和臺灣道裕鐸在打狗會面，裕鐸在會談中告知船長，外國商船如果直接在安平停泊，並不符合規定，臺灣道將受到朝廷處罰，但裕鐸和打狗地方官員可以私下允許外國商船，停靠遠離政治核心的打狗進行貿易。
然而，實際上官員後來往往放任外國商船停靠安平，未能嚴格執行禁令。過了數年，新任的臺灣道孔昭慈於 1859 年，又要求外國商船「不准像之前一樣在安平附近起卸貨物」。有位英國商人分析：「這並非臺灣道刻意禁止外商在臺灣府貿易，而是因為府城當地泉州人組成的商人團體，跑去向福建巡撫告狀，指控外國商船收購物產，造成物價上漲，影響了本地商人的生意。」
臺灣道：臺灣建省前，在臺灣的最高文官。

根據上文，外國商人分析臺灣道重申外國商船不得在安平附近起卸貨物的原因，最可能與下列何者有關？', '[{"key":"A","text":"安平與鹿耳門泥沙淤積，易造成擱淺"},{"key":"B","text":"府城商人透過「郊」來維護自身利益"},{"key":"C","text":"日本出兵臺灣南部，清帝國提高警戒"},{"key":"D","text":"許多府城商人組成「郊」與洋行合作"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '111 年',
      'https://knowledgeatlas.cc/history/', array['tw-province-1885', 'cn-arrowwar-1856']::text[], 99,
      '原網站事件「英法聯軍」自動對應。', 1, 'draft'
    ),
    (
      'ka-jh-set2-g04-q1', 'h3c6-02', 'past',
      '閱讀下列選文，回答下列各題：
1900 年，在慈禧太后默許民眾攻擊教堂及傳教士，甚至包圍北京的外國使館後，美軍第十五步兵團首次被派遣至中國保護僑民。清朝滅亡後，步兵團為確保美國人在華利益，長期駐守天津。袁世凱死後至北伐完成期間，中國內戰不斷，步兵團為避免動亂影響美國的利益，也曾介入其中，間接保護了天津民眾的安全。後來，當日本在今日北京附近發動侵華的軍事行動，與中國爆發戰爭，美國政府不願捲入戰局，因此決定撤離第十五步兵團，結束多年的派駐。

根據上文，美國首次派遣第十五步兵團至中國的原因，最可能是下列何者？', '[{"key":"A","text":"鴉片戰爭結束後，要求給予特權"},{"key":"B","text":"趁英法聯軍之際，脅迫開放天津"},{"key":"C","text":"與列強瓜分中國，從中獲得利益"},{"key":"D","text":"義和團事件爆發，引發八國聯軍"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'D', '', '會考', '109 年',
      'https://knowledgeatlas.cc/history/', array['cn-warjapan-1937', 'cn-hundred-days-1898']::text[], 99,
      '依題幹與答案複核：題組第一題答案為義和團與八國聯軍。', 4, 'draft'
    ),
    (
      'ka-jh-set2-g04-q2', 'h4c1-06', 'past',
      '閱讀下列選文，回答下列各題：
1900 年，在慈禧太后默許民眾攻擊教堂及傳教士，甚至包圍北京的外國使館後，美軍第十五步兵團首次被派遣至中國保護僑民。清朝滅亡後，步兵團為確保美國人在華利益，長期駐守天津。袁世凱死後至北伐完成期間，中國內戰不斷，步兵團為避免動亂影響美國的利益，也曾介入其中，間接保護了天津民眾的安全。後來，當日本在今日北京附近發動侵華的軍事行動，與中國爆發戰爭，美國政府不願捲入戰局，因此決定撤離第十五步兵團，結束多年的派駐。

根據上文，第十五步兵團介入中國內戰，間接保護天津民眾安全，當時中國的主要政治情況為何？', '[{"key":"A","text":"立憲派與革命派爭論不休，滿清帝制搖搖欲墜"},{"key":"B","text":"地方軍事強人憑藉武力以奪取地盤，割據一方"},{"key":"C","text":"日本扶植汪精衛政權，對抗在重慶的國民政府"},{"key":"D","text":"國民黨與共產黨不斷衝突，共黨全面控制中國。\n汪精衛＝汪兆銘"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'B', '', '會考', '109 年',
      'https://knowledgeatlas.cc/history/', array['cn-warjapan-1937', 'cn-hundred-days-1898']::text[], 99,
      '依題幹與答案複核：題組第二題答案為軍閥割據。', 4, 'draft'
    ),
    (
      'ka-jh-set2-g04-q3', 'h4c3-08', 'past',
      '閱讀下列選文，回答下列各題：
1900 年，在慈禧太后默許民眾攻擊教堂及傳教士，甚至包圍北京的外國使館後，美軍第十五步兵團首次被派遣至中國保護僑民。清朝滅亡後，步兵團為確保美國人在華利益，長期駐守天津。袁世凱死後至北伐完成期間，中國內戰不斷，步兵團為避免動亂影響美國的利益，也曾介入其中，間接保護了天津民眾的安全。後來，當日本在今日北京附近發動侵華的軍事行動，與中國爆發戰爭，美國政府不願捲入戰局，因此決定撤離第十五步兵團，結束多年的派駐。

根據上文，美國決定撤離第十五步兵團，最可能與下列何者有關？', '[{"key":"A","text":"九一八事變"},{"key":"B","text":"西安事變"},{"key":"C","text":"盧溝橋事變"},{"key":"D","text":"珍珠港事變"}]'::jsonb, '[]'::jsonb, '[]'::jsonb,
      'C', '', '會考', '109 年',
      'https://knowledgeatlas.cc/history/', array['cn-warjapan-1937', 'cn-hundred-days-1898']::text[], 99,
      '依題幹與答案複核：題組第三題答案為盧溝橋事變。', 4, 'draft'
    )
)
insert into public.history_questions (
  question_code, event_id, question_type, prompt, options, media_urls, question_tables,
  answer, explanation, source_name, source_year, source_url, original_event_ids,
  mapping_confidence, mapping_note, display_order, status
)
select
  seed.question_code, event.id, seed.question_type, seed.prompt, seed.options, seed.media_urls,
  seed.question_tables, seed.answer, seed.explanation, seed.source_name, seed.source_year,
  seed.source_url, seed.original_event_ids, seed.mapping_confidence, seed.mapping_note,
  seed.display_order, seed.status
from seed_questions seed
join public.history_events event on event.event_code = seed.event_code
on conflict (question_code) do nothing;

do $$
declare
  seeded_count integer;
begin
  select count(*) into seeded_count
  from public.history_questions
  where question_code in (
      'ka-jh-set1-s002',
      'ka-jh-set1-s004',
      'ka-jh-set1-s010',
      'ka-jh-set1-s012',
      'ka-jh-set1-s015',
      'ka-jh-set1-s017',
      'ka-jh-set1-s029',
      'ka-jh-set1-s030',
      'ka-jh-set1-s031',
      'ka-jh-set1-s038',
      'ka-jh-set1-s040',
      'ka-jh-set1-s049',
      'ka-jh-set1-s054',
      'ka-jh-set1-s060',
      'ka-jh-set1-s061',
      'ka-jh-set1-s068',
      'ka-jh-set1-s072',
      'ka-jh-set1-s073',
      'ka-jh-set1-s074',
      'ka-jh-set1-s077',
      'ka-jh-set1-s079',
      'ka-jh-set1-s082',
      'ka-jh-set1-s083',
      'ka-jh-set1-s091',
      'ka-jh-set1-s093',
      'ka-jh-set1-s094',
      'ka-jh-set1-s095',
      'ka-jh-set1-s099',
      'ka-jh-set1-s103',
      'ka-jh-set1-s106',
      'ka-jh-set1-s110',
      'ka-jh-set1-s113',
      'ka-jh-set1-s116',
      'ka-jh-set1-s126',
      'ka-jh-set1-s128',
      'ka-jh-set1-s144',
      'ka-jh-set1-s146',
      'ka-jh-set1-s153',
      'ka-jh-set1-s164',
      'ka-jh-set1-s172',
      'ka-jh-set1-s177',
      'ka-jh-set1-s181',
      'ka-jh-set1-s186',
      'ka-jh-set1-s188',
      'ka-jh-set1-s199',
      'ka-jh-set1-s200',
      'ka-jh-set1-s209',
      'ka-jh-set1-s218',
      'ka-jh-set1-s226',
      'ka-jh-set1-s227',
      'ka-jh-set1-s228',
      'ka-jh-set1-s230',
      'ka-jh-set1-s234',
      'ka-jh-set1-s235',
      'ka-jh-set1-s236',
      'ka-jh-set1-s238',
      'ka-jh-set1-s239',
      'ka-jh-set1-s240',
      'ka-jh-set1-s246',
      'ka-jh-set1-s253',
      'ka-jh-set1-s255',
      'ka-jh-set1-s259',
      'ka-jh-set1-s262',
      'ka-jh-set1-g06-q1',
      'ka-jh-set1-g06-q2',
      'ka-jh-set1-g06-q3',
      'ka-jh-set1-g07-q1',
      'ka-jh-set1-g07-q2',
      'ka-jh-set2-s003',
      'ka-jh-set2-s005',
      'ka-jh-set2-s008',
      'ka-jh-set2-s009',
      'ka-jh-set2-s010',
      'ka-jh-set2-s012',
      'ka-jh-set2-s018',
      'ka-jh-set2-s022',
      'ka-jh-set2-s024',
      'ka-jh-set2-s029',
      'ka-jh-set2-s032',
      'ka-jh-set2-s033',
      'ka-jh-set2-s035',
      'ka-jh-set2-s036',
      'ka-jh-set2-s037',
      'ka-jh-set2-s042',
      'ka-jh-set2-s043',
      'ka-jh-set2-s045',
      'ka-jh-set2-s046',
      'ka-jh-set2-s047',
      'ka-jh-set2-s051',
      'ka-jh-set2-s054',
      'ka-jh-set2-s055',
      'ka-jh-set2-s057',
      'ka-jh-set2-s063',
      'ka-jh-set2-s066',
      'ka-jh-set2-s067',
      'ka-jh-set2-s070',
      'ka-jh-set2-s071',
      'ka-jh-set2-s072',
      'ka-jh-set2-s074',
      'ka-jh-set2-s075',
      'ka-jh-set2-s076',
      'ka-jh-set2-s078',
      'ka-jh-set2-s082',
      'ka-jh-set2-s083',
      'ka-jh-set2-s084',
      'ka-jh-set2-s086',
      'ka-jh-set2-s090',
      'ka-jh-set2-s093',
      'ka-jh-set2-s095',
      'ka-jh-set2-s098',
      'ka-jh-set2-s101',
      'ka-jh-set2-s113',
      'ka-jh-set2-s122',
      'ka-jh-set2-s130',
      'ka-jh-set2-s132',
      'ka-jh-set2-s137',
      'ka-jh-set2-s138',
      'ka-jh-set2-s142',
      'ka-jh-set2-s144',
      'ka-jh-set2-s146',
      'ka-jh-set2-s148',
      'ka-jh-set2-s149',
      'ka-jh-set2-s151',
      'ka-jh-set2-s152',
      'ka-jh-set2-s155',
      'ka-jh-set2-s164',
      'ka-jh-set2-s169',
      'ka-jh-set2-s177',
      'ka-jh-set2-s183',
      'ka-jh-set2-s188',
      'ka-jh-set2-s194',
      'ka-jh-set2-s196',
      'ka-jh-set2-s201',
      'ka-jh-set2-s203',
      'ka-jh-set2-s205',
      'ka-jh-set2-s210',
      'ka-jh-set2-s212',
      'ka-jh-set2-s214',
      'ka-jh-set2-s219',
      'ka-jh-set2-s221',
      'ka-jh-set2-s222',
      'ka-jh-set2-s227',
      'ka-jh-set2-s229',
      'ka-jh-set2-s234',
      'ka-jh-set2-g01-q1',
      'ka-jh-set2-g01-q2',
      'ka-jh-set2-g04-q1',
      'ka-jh-set2-g04-q2',
      'ka-jh-set2-g04-q3'
  );

  if seeded_count <> 149 then
    raise exception '歷史正式題庫應有 149 題，實際只有 % 題。請檢查事件對應。', seeded_count;
  end if;
end
$$;
