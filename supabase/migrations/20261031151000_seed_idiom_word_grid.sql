-- 由 scripts/generate-idiom-word-grid-seed.mjs 產生。
-- 教育部《成語典》資料保留原文，不自行改寫；網站連結供查證。

begin;

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('一心一意', '同心同意。亦用於指心意專一，毫無他念。＃語本《杜氏新書》。

△「全心全意」', '＃《杜氏新書》（據《三國志．卷一六．魏書．杜畿傳》裴松之注引）1>

喜欲恕折節謝己，諷司馬宋權示之以微意。恕答權書曰：「況示委曲。夫法天下事，以善意相待，無不致快也；以不善意相待，無不致嫌隙也。而議者言，凡人天性皆不善，不當待以善意，更墮其調中。僕得此輩，便欲歸蹈滄海乘桴耳，不能自諧在其間也。然以年五十二，不見廢棄，頗亦遭明達君子亮其本心；若不見亮，使人刳心著地，正與數斤肉相似，何足有所明，故終不自解說。程征北功名宿著，在僕前甚多，有人出征北乎！若令下官事無大小，咨2>而後行，則非上司彈繩3>之意；若咨而不從，又非上下相順之宜。故推一心，任一意，直而行之耳。殺胡之事，天下謂之是邪，是僕諧也；呼為非邪，僕自受之，無所怨咎。程征北明之亦善，不明之亦善，諸君子自共為其心耳，不在僕言也。」喜於是遂深文劾恕。
〔注解〕

典故或見於唐．駱賓王〈代女道士王靈妃贈道士李榮〉詩。

咨：徵詢；商量。

彈繩：木匠彈繩墨以取直。比喻定下準則。

〔參考資料〕
唐．駱賓王〈代女道士王靈妃贈道士李榮〉詩（據《全唐詩．卷七七．駱賓王》引）

寄語天上弄機人，寄語河邊值查客。乍可匆匆共百年，誰使遙遙期七夕。想知人意自相尋，果得深心共一心。一心一意無窮已，投漆投膠非足擬。', '「一心一意」出自於《三國志》裴松之注引《杜氏新書》。其中記載，三國時魏國大臣杜恕在寫給上司宋權的一封信中說到：「若令下官事無大小，咨而後行，則非上司彈繩之意；若咨而不從，又非上下相順之宜。故推一心，任一意，直而行之耳。」意思是自己雖為下屬，但如果做任何事都要先問過上司，那麼上司訂定的原則就沒有意義了；假使問了又不能按照上司的決定去做，也是不應該。所以在很多事上，就自己作主了。其中「推一心，任一意」是指揣測上司的想法，與上司同心。「一心一意」就表示同心同意的意思，如《二刻拍案驚奇》卷三六：「他不拘一文二文，常自喜不吝捨。他妻子見慣了的，況是女流，愈加信佛，也自與他一心一意，雖是生意淺薄，不多大事，沒有一日不捨兩文的。」「一」也有專注的意思，因此後世也用「一心一意」表示心意專一之意。如唐．駱賓王〈代女道士王靈妃贈道士李榮〉詩：「一心一意無窮已，投漆投膠非足擬。」指兩人的情感濃厚、專一，無窮無盡，用如膠似漆都無法形容。後來「一心一意」這個成語就從「推一心，任一意」演變而出，被用來表示同心同意或心意專一，毫無他念的意思。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1324&webMd=2&la=0', '', 'elementary', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('心平氣和', '心氣平和，不急不怒。語本《左傳．昭公二十年》。

△「平心靜氣」', '《左傳．昭公二十年》

齊侯至自田，晏子侍于遄臺，子猶馳而造焉。公曰：「唯據與我和夫！」晏子對曰：「據亦同也，焉得為和？」公曰：「和與同異乎？」對曰：「異。……先王之濟五味、和五聲也，以平其心，成其政也。聲亦如味，一氣、二體、三類、四物、五聲、六律、七音、八風、九歌，以相成也；清濁、大小、短長、疾徐，哀樂、剛柔，遲速、高下、出入、周疏，以相濟也。君子聽之，以平其心，心平德和。故《詩》曰：『德音不瑕1>。』今據不然。君所謂可，據亦曰可；君所謂否，據亦曰否。若以水濟水，誰能食之？若琴瑟之專壹，誰能聽之？同之不可也如是。」
〔注解〕

德音不瑕：德音是沒有瑕疵的。出自《詩經．豳風．狼跋》。瑕，音ㄒㄧㄚˊ，瑕疵、缺點。', '「心平氣和」原作「心平德和」。晏子，即晏嬰，春秋齊國人，在齊景公時任宰相，為當時的名臣。據《左傳．昭公二十年》載，有一天，景公遊獵回來，與大臣梁丘據等在遄臺飲酒作樂。當景公對人生有所感慨時，梁丘據亦在一旁附和，故景公說：「只有據與我是相和的啊！」隨侍在側的晏子不以為然，他說：「據和你不過是相同而已，那裡有相和！」景公訝異地問：「『和』跟『同』有什麼不一樣嗎？」晏子回答說：「若以烹調為例，在熬煮羹湯時，會適切地把不同佐料相混，使之味道調和，才做出美味的料理。君臣相處之道也是這樣的。當君王提出一個主張時，作為臣子的應該是從不同角度給予建言，使君王的施為更為完備，而不是一昧地附和而已。再以音樂為例，一篇好的樂章，是各種音符以不同的快慢、高低……組合在一起，互相搭配，調和出優美的音樂，使君子聽了，內心能得到平靜，德行能趨向平和。所以《詩經》說：德音是沒有瑕疵的。像梁丘據這樣只會對君王的說法同聲應合，就好像把清水加到清水裡去調味，誰會想去吃它呢？又好像琴瑟只彈一個單一的音符，誰會想去聽它呢？所以『同』是不好的啊！」此處的「心平德和」指的是心情的平靜，德行修養的平和。有此境界，人的脾氣自然會溫和不暴躁，所以後來由此演變成「心平氣和」這句成語，形容心氣平和，不急不怒。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1097&webMd=2&la=0', '', 'elementary', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('和氣生財', '生意人的口頭語，意指態度溫和而不得罪顧客，才會致富。如：「做生意講求和氣生財，盡心服務客人，不與客人起無謂的爭執。」', '', '', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=10108&webMd=2&la=0', '', 'elementary', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('生財有道', '語本《禮記．大學》：「生財有大道。」形容擅長發財致富。元．錢霖〈哨遍．試把賢愚窮究套．五煞〉：「乾生受，生財有道，受用無由。」', '', '', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=7802&webMd=2&la=0', '', 'elementary', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('自相矛盾', '比喻言語或行事前後無法呼應，互相牴觸。◎典出《韓非子．難一》。', '《韓非子．難一》

楚1>人有鬻2>楯3>與矛者，譽之曰：「吾楯之堅，物莫能陷4>也。」又譽其矛曰：「吾矛之利，於物無不陷也。」或曰：「以子之矛，陷子之楯，何如？」其人弗能應5>也。夫不可陷之楯，與無不陷之矛，不可同世而立。今堯、舜之不可兩譽，矛楯之說也。
〔注解〕

楚：國名，周成王封熊繹於楚，春秋時稱王，為戰國七雄之一，領有今湖南、湖北、安徽、浙江及河南南部，後為秦所滅。

鬻：音ㄩˋ，賣。

楯：音ㄕㄨㄣˇ，通「盾」。古代用來抵禦敵人兵刃及保護自己的兵器。

陷：指刺入。

弗能應：無法回答。

兩譽：堯、舜兩人同時都得到最高的讚美。

《韓非子．難勢》

客曰：「人有鬻矛與楯者，譽其楯之堅，物莫能陷也。俄而又譽其矛曰：『吾矛之利，物無不陷也。』人應之曰：『以子之矛，陷子之楯，何如？』其人弗能應也。」', '矛是攻擊的兵器，而盾是用來防禦兵器攻擊的器具。在《韓非子．難一》中，舉了一個故事說：有個楚國人在市集上賣矛和盾。剛開始時先是誇讚他的盾說：「我這面盾非常堅固，任何鋒利的東西都刺不破它。」過了一會兒，又誇讚他的矛說：「我這隻矛是最鋒利的，沒有什麼東西是它不能刺破的。」這時，有人緊接著問說：「如果用你的矛刺你的盾，那結果會是怎樣呢？」這一問，讓賣矛與盾的人無言以對。典源又見《韓非子．難勢》。後來這個故事被濃縮成「自相矛盾」，用來比喻言語或行事前後無法呼應，互相牴觸。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=89&webMd=2&la=0', '', 'elementary', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('相得益彰', '「相得益彰」之「彰」，典源作「章」。指互相配合、映襯，更能顯出各自的優點。語本漢．王襃〈聖主得賢臣頌〉。

△「相映成趣」、「聚精會神」', '漢．王襃〈聖主得賢臣頌〉（據《漢書．卷六四下．嚴朱吾丘主父徐嚴終王賈傳．王襃》引）

昔賢者之未遭遇也，圖事揆策則君不用其謀，陳見悃誠則上不然其信，進仕不得施效，斥逐又非其愆。是故伊尹勤於鼎俎，太公困於鼓刀，百里自鬻，甯子飯牛，離此患也。及其遇明君遭聖主也，運籌合上意，諫諍即見聽，進退得關其忠，任職得行其術，去卑辱奧渫而升本朝，離疏釋蹻而享膏粱，剖符錫壤而光祖考，傳之子孫，以資說士。故世必有聖知之君，而後有賢明之臣。故虎嘯而（冽風）［風冽〕，龍興而致雲，蟋蟀俟秋唫，蜉蝤出以陰。《易》曰：「飛龍在天，利見大人。」《詩》曰：「思皇多士，生此王國。」故世平主聖，俊艾1>將自至，若堯、舜、禹、湯、文、武2>之君，獲稷3>、契4>、皋陶5>、伊尹6>、呂望7>，明明8>在朝，穆穆9>列布10>，聚精會神11>，相得益章。雖伯牙操遞鍾，逢門子彎烏號，猶未足以喻其意也。
〔注解〕

俊艾：賢德之人。艾，通「乂」，音一ˋ，才德出眾。

堯、舜、禹、湯、文、武：指唐堯、虞舜、夏禹、商湯、周文王及周武王六個聖主。

稷：后稷，周朝的先祖，生卒年不詳。相傳姜原因為踏到天帝的足跡，而懷了后稷。生下孩子後，最初想要將他丟棄，因此取名為棄。長大後，帝堯舉薦他為農師，因有功績，被封於邰，號曰「后稷」。

契：殷代始祖。高辛氏的兒子，生卒年不詳，堯時為司徒，封於商。音ㄒ一ㄝˋ。

皋陶：音ㄍㄠ　一ㄠˊ，生卒年不詳。相傳為舜的臣子，掌管刑獄事務。

伊尹：名摯，生卒年不詳，商初賢相。商的開國君主湯死後，繼承君位的孫子太甲無道，伊尹將他放逐到桐宮，等到太甲悔過後，再迎回復位。

呂望：指周初賢臣呂尚。字子牙，東海人，生卒年不詳。本姓姜，他的先祖封於呂，所以稱為「呂尚」。周文王出外打獵時，和他相遇於渭水河邊，相談甚歡，說道：「我的太公（父親）盼望一位能輔佐周朝的人，你真的是那個人嗎？你讓我的太公盼望好久啊！」因此呂尚又號「太公望」。周文王立他為師。後佐武王擊敗商朝，封於齊，後世稱為「姜太公」。

明明：明舉賢才。

穆穆：威儀盛大的樣子。

列布：排列分布。

聚精會神：心神聚合，會集眾人的智慧。見「聚精會神」。', '「相得益彰」原作「相得益章」。「彰」，明顯、彰顯的意思，「相得益彰」是指彼此互相配合、映襯，更能顯出各自的長處。《漢書．卷六四下．嚴朱吾丘主父徐嚴終王賈傳．王襃》中收錄王襃的一篇文章〈聖主得賢臣頌〉。內容主要在述說聖主和賢臣之間的關係。他認為賢才是國家的工具，官員如果是賢能的人才，則不需任何的改革更張，功德自然就會普及全國。工具銳利，用的力量少，但效果卻很好。相同的道理，聖人和君子，正是聖明君主治理天下的工具，因此君王必須認真尋找賢德之人，才能夠安逸地享受天下太平。做部屬的也是如此，賢能的人一旦遇到聖明的君主，謀略合乎君主的心意，規諫的言詞受到重視，忠君之心能夠彰顯，得以擔任官職且施展抱負。所以天下太平，君主聖明，賢能的人才自然聚集，眾人心神聚合，會集大家的智慧，互相勉勵、配合，更能顯現出各自的長處。「相得益彰」這句成語就出自此處，指互相配合、映襯，更能顯出各自的優點。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1325&webMd=2&la=0', '', 'elementary', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('益壽延年', '義參「延年益壽」。見「延年益壽」條。', '此處所列為「延年益壽」之典源，提供參考。
東周戰國．宋玉〈高唐賦并序〉（據《文選．卷一九．賦》引）

昔者楚襄王與宋玉遊於雲夢之臺，望高唐之觀，其上獨有雲氣，崒兮直上，忽兮改容，須臾之間，變化無窮。王問玉曰：「此何氣也？」玉對曰：「所謂朝雲者也。」王曰：「何謂朝雲？」玉曰：「昔者先王嘗遊高唐，怠而晝寢，夢見一婦人曰：『妾，巫山之女也。爲高唐之客。聞君遊高唐，願薦枕席。』王因幸之。去而辭曰：『妾在巫山之陽，高丘之阻，旦為朝雲，暮為行雨。朝朝暮暮，陽臺之下。』旦朝視之，如言。故為立廟，號曰『朝雲』。」……王將欲往見，必先齋戒1>，差2>時擇日，簡輿玄服3>。建雲斾4>，蜺為旌5>，翠為蓋6>。風起雨止，千里而逝。蓋發蒙7>，往自會。思萬方，憂國害，開賢聖，輔不逮。九竅8>通鬱，精神察滯，延年益壽千萬歲。
〔注解〕

齋戒：在祭祀或舉行重要典禮之前，沐浴更衣，不飲酒，不吃葷，夫妻不同房，嚴守戒律，以示虔誠莊敬。

差：音ㄔㄞ，選擇。

簡輿玄服：減省車馬隨從，穿上黑色衣服。

雲斾：有雲彩紋飾的大旗。斾，同「旆」，音ㄆㄟˋ。

蜺為旌：裝飾著五彩羽毛的旗子。蜺，同「霓」，音ㄋ一ˊ，彩虹。

翠為蓋：用翠鳥羽毛裝飾的車蓋。

發蒙：啟發蒙昧。

九竅：指人身上的九個孔竅，包含兩眼、兩耳、兩鼻孔、口及排尿口、肛門。', '此處所列為「延年益壽」之典故說明，提供參考。
宋玉（約前２９８年—約前２２２年），為戰國後期楚國的辭賦家。他寫下了不少傳世經典的作品，譬如〈高唐賦〉、〈神女賦〉及〈登徒子好色賦〉等。〈高唐賦〉這篇作品由序及正文兩部分組成，序的部分藉著描寫楚襄王與宋玉遊於雲夢之臺，遠望高唐的景觀，看到高唐上方的雲氣千變萬化，進而帶出過去楚懷王也曾經遊覽高唐，並在夢中遇見巫山神女的情景。後面的正文則分別描述了高唐地區的山川地形景觀，首先是雨過天晴之後，百川匯聚，水勢洶湧澎湃的情狀。又山中草木繁茂雜生，風吹枝條所發出的悲鳴聲，令人動容。至於山勢險峻，岩石參差堆疊，望去又令人驚心動魄。另外還寫出仙人在高唐聚會祈禱，以及楚王奏樂田獵的盛況。整篇文章在極盡排比鋪寫後，最後才進入主題，指出楚王的心裡應該想著百姓，為國家的禍福憂心，任用賢能的人來輔助自己才能的不足。如此一來，不僅身上九竅得以暢通，精神更加清朗，壽命自然能綿延到千萬歲。後來原文中的「延年益壽」被摘出，成為一句成語，用來指拉長歲數，增加壽命。多作為頌祝人長壽的用詞。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=78494&webMd=2&la=0', '', 'elementary', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('年富力強', '正值壯年，精力旺盛，大有作為。《明史．卷六九．選舉志一》：「務求學行兼優，年富力強，累試優等者，乃以充貢。」《醒世恆言．卷二．三孝廉讓產立高名》：「二弟年富力強，方司民社，宜資莊產，以終廉節。」', '', '', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=6787&webMd=2&la=0', '', 'elementary', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('強詞奪理', '「強詞奪理」之「奪」，典源作「昧」。形容沒有道理卻強為狡辯，硬說成有理。語本唐．神清《北山錄．卷三．合霸王》。', '唐．神清《北山錄．卷三．合霸王》

三國初，吳人未甚信。天竺沙門康僧會始造於吳，締搆行道，孫權以為誣。……孫皓狂虐不道，國將病矣！初廢毀淫祠，延及寺宇，群臣議曰︰「佛之威力不並餘神，僧會感靈。太皇創寺，今若輕廢，恐貽後悔。皓意未謂之然，使張昱至寺詰會，會才辯奇拔，昱不能加，乃復于皓。皓1>大集公卿洎2>庶寮3>，徵會以車馬，既至，皓強詞昧理，取會不及已。而會酬抗盡典謨之體，推引叶忠良之議。皓然知其不可屈，乃革容而敬焉。
〔注解〕

皓：孫皓（西元２４２∼２８４），三國吳皇帝，字元宗，一名彭祖，字皓宗。孫皓個性專橫殘暴，奢侈荒淫，大失民心。天紀四年，晉武帝六路出兵攻吳，皓出降，在位十六年，後封為歸命侯。

洎：音ㄐㄧˋ。到、及。

庶寮：眾官。寮，同「僚」。', '「強詞奪理」原作「強詞昧理」。佛教約於東漢明帝時正式傳入中國，但一直僅流傳於北方，並未傳入江南。直到東漢末年，部分佛教徒為了躲避中原的戰亂，遷居吳地，佛教才隨之進入江南。據唐．神清《北山錄．卷三．合霸王》載，東吳孫權赤烏年間，天竺僧人康僧會為在江南弘法，來到建業，奉勸孫權信佛並建寺塔，顯佛骨舍利神蹟，於是孫權命人建塔十三座，自此篤信佛教。後來孫皓繼位，他暴虐無道，施行苛政，並要拆毀廟宇，褻瀆神佛。眾臣力勸不可，他們認為佛之能力跟其餘眾神不同，且佛塔是先王所建，若輕易拆毀，恐怕會遭到天譴，到時就後悔莫及了。孫皓因此猶豫不決，決定派張昱先去會見僧會，試探他的實力。張昱年輕好辯，又不信鬼神之事，向僧會提出了不少詰難。僧會雖已年老，但面對張昱的詰問仍回答得頭頭是道，使張昱無懈可擊，反被折服，只得回去向孫皓覆命。孫皓知道了僧會的辯才無礙之後，更想見他一面，於是召集了公卿百官，又派人去接僧會入宮。僧會來到宮中之後，孫皓也提出許多問題想要辯倒僧會，他問僧會說：「佛教所宣揚的是什麼道理呢？」僧會回答：「是視眾生平等。君王能夠愛民，使人民安居樂業；人民能懂孝悌仁義，互相友愛。」孫皓聽了之後又說：「這不都是孔孟的道理嗎？」僧會回答：「佛法與孔孟之道有相同之處，也有不同之處。孔孟主要傳揚人倫，這點與佛法是一樣的，但是佛法更加廣泛，提及因緣生滅、諸行無常，這則是孔孟之道所沒有的。」孫皓雖然強自狡辯，但仍無法辯倒僧會，也就不敢隨便毀壞廟宇佛像了。後來「強詞奪理」這句成語，就從這裡的原文「強詞昧理」演變而出，用來形容沒有道理卻強行狡辯，硬說成有理。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=227&webMd=2&la=0', '', 'elementary', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('事半功倍', '事情只用古人一半的心力，而功效加倍。形容費力少而收效大。語本《孟子．公孫丑上》。後用「事半功倍」比喻工作效率高。

△「以解倒懸」、「事倍功半」、「飢不擇食」、「渴不擇飲」', '《孟子．公孫丑上》

（孟子）曰：「文王何可當也，由湯至於武丁，賢聖之君六七作，天下歸殷久矣，久則難變也。……夏后殷周之盛，地未有過千里者也，而齊有其地矣。雞鳴狗吠相聞，而達乎四境，而齊有其民矣。地不改辟矣，民不改聚矣，行仁政而王，莫之能禦也。且王者之不作，未有疏於此時者也。民之憔悴於虐政，未有甚於此時者也。飢者易為食，渴者易為飲。孔子曰：『德之流行，速於置郵而傳命。』當今之時，萬乘之國1>行仁政，民之悅之，猶解倒懸2>也。故事半古之人，功必倍之，惟此時為然。」
〔注解〕

萬乘之國：擁有萬輛兵車的國家。指大國。乘，音ㄕㄥˋ，古代計算車輛的單位，四馬一車名乘。

倒懸：縛人兩足倒掛，比喻極為困苦。', '戰國齊人公孫丑是孟子弟子，他曾經問孟子：「如果夫子掌握齊國大權，可以建立和管仲、晏嬰那樣的功業嗎？」孟子不願意被拿來和管仲相比，認為幫助齊國統一天下是件很容易的事。比起之前的夏、商、周三代，現今的齊國不但國土廣大，而且人民眾多，加上以王道來治理天下的聖明君主很久沒有出現，以致人民長久處在暴政之中，他們心中渴望施行仁政的程度和「肚子餓的人只求吃飽，口渴的人只求解渴」一樣。所以齊國若在此時施行仁政，將正應驗孔子說的：「德行流傳的速度，比驛馬傳達命令還快。」而人民心裡喜悅的程度，會就像脫離兩腳被綁住倒掛的困境一樣。這和古時候的人相比，只要花費一半的心力，就能達到加倍的功效。後來「事半功倍」這句成語就從這裡演變而出，用來比喻工作效率高。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=273&webMd=2&la=0', '', 'junior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('功成名就', '事業有所成就，而且有名望。元．范康《竹葉舟》第二折：「你則說做官的功成名就，我則說出家的延年益壽。」也作「功就名成」、「功成名立」、「功成名遂」。', '', '', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=15425&webMd=2&la=0', '', 'junior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('名列前茅', '茅，通「旄」。旄，旄牛。前茅，古代行軍打仗時，前行的兵士所拿的竿頂用旄牛尾裝飾的指揮旗幟。一說茅即茅草，春秋時代楚國行軍，有人拿著茅草當旗幟走在軍隊前面，或擔任斥候。「名列前茅」，指其名列於隊伍前面。語本《左傳．宣公十二年》。後用「名列前茅」比喻成績優異，名次排在前面。

△「獨占鰲頭」', '《左傳．宣公十二年》

夏，六月，晉師救鄭。荀林父將中軍，先縠佐之；士會將上軍，郤克佐之；趙朔將下軍，欒書佐之。趙括、趙嬰齊為中軍大夫，鞏朔、韓穿為上軍大夫，荀首、趙同為下軍大夫，韓厥為司馬。及河，聞鄭既及楚平，桓子欲還，曰：「無及於鄭而勦民，焉用之？楚歸而動，不後。」隨武子曰：「善。會聞用師，觀釁而動。德刑政事典禮不易，不可敵也，不為是征。楚軍討鄭，怒其貳而哀其卑，叛而伐之，服而舍之，德刑成矣。伐叛，刑也；柔服，德也。二者立矣。昔歲入陳，今茲入鄭，民不罷勞，君無怨讟，政有經矣。荊尸而舉，商、農、工、賈不敗其業，而卒乘輯睦，事不奸矣。蒍敖1>為宰2>，擇楚國3>之令典4>，軍行，右轅5>，左追蓐6>，前茅7>慮無8>，中權9>，後勁10>，百官象物而動11>，軍政不戒而備，能用典矣。其君之舉也，內姓選於親，外姓選於舊。舉不失德，賞不失勞。老有加惠，旅有施舍。君子小人，物有服章，貴有常尊，賤有等威，禮不逆矣。德立，刑行，政成，事時，典從，禮順，若之何敵之？見可而進，知難而退，軍之善政也。兼弱攻昧，武之善經也。子姑整軍而經武乎，猶有弱而昧者，何必楚？仲虺有言曰：『取亂侮亡。』兼弱也。〈汋〉曰：『於鑠王師，遵養時晦。』耆昧也。〈武〉曰：『無競惟烈。』撫弱耆昧以務烈所，可也。」彘子曰：「不可。晉所以霸，師武臣力也。今失諸侯，不可謂力。有敵而不從，不可謂武。由我失霸，不如死。且成師以出，聞敵彊而退，非夫也。命有軍師，而卒以非夫，唯群子能，我弗為也。」以中軍佐濟。
〔注解〕

蒍敖：孫叔敖，春秋楚人，生卒年不詳。蒍賈之子。兒時於路上見兩頭蛇，聞人言，見此蛇者必死，自以為將死，而恐後人見之又死，乃殺而埋之。及長，性恭儉，代虞丘為楚相，施教導民，三月而楚大治。彼曾三得相而不喜，三去相而不悔，不以得失為意，史稱循吏。蒍，音ㄨㄟˇ。

宰：太宰，統理百官之長。

楚國：周成王封熊繹於楚，春秋時稱王，為戰國七雄之一。領有今湖南、湖北、安徽、浙江及河南南部，後為秦所滅。

令典：好的典章法度。

轅：車前駕牲畜的兩根直木，此指跟隨在主將車轅旁備戰。

追蓐：追尋可做席墊的草，割之以備用。蓐，音ㄖㄨˋ，草墊子。

前茅：稱軍中的偵察敵情的哨兵，又稱「斥候」。古代斥候，以旄旌（竿頂以旄牛尾裝飾的指揮旗幟）或茅草為標幟，看到前方的敵人，則舉旌以報告在後面的軍隊戒備。

慮無：戒備意外。

中權：中軍制定謀略。

後勁：後軍精良。

象物而動：根據旌旗的指揮而行動。', '據《左傳．宣公十二年》載，春秋時代，楚國攻打鄭國，晉國派兵援鄭，但晉軍抵達前鄭國就已投降，晉軍統帥荀林父（ㄈㄨˇ）於是打算班師回朝。上軍主將士會支持荀林父的決定，因為他認為現在的楚國德行、刑罰、政令、事務、典章、禮儀都具備周全，根本無法與之為敵。在分析到楚國軍力時，他曾說道：「軍行，右轅，左追蓐，前茅慮無，中權，後勁。」意思是：楚國軍隊紀律嚴明，行軍之時，右軍緊隨在主將車轅旁備戰，左軍負責割草以備休息用，前軍的哨兵偵察敵情極為慎重，中軍依情報制定謀略，後軍則十分精良，整個部隊實力雄厚，難與抗衡。士會話中的「前茅」，指的便是行軍時置於最前方，負責偵察敵情的哨兵。古代作戰時，前鋒部隊是以旄旌或茅草作為識別標誌，一旦偵察到敵方位置，就舉之而告知後方軍隊加強戒備，故以「前茅」稱此負責偵察的前軍。後來「前茅」引申有排名在前的意思，而「名列前茅」則可用來比喻成績優異，名次排在前面。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1347&webMd=2&la=0', '', 'junior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('茅塞頓開', '被茅草阻塞的山路，豁然開通了。比喻閉塞的心思，頓時豁然了悟。語本《孟子．盡心下》。', '《孟子．盡心下》

孟子謂高子1>曰：「山徑之蹊間，介然2>用之而成路；為間3>不用，則茅塞4>之矣。今茅塞子之心矣。」
〔注解〕

高子：戰國時齊人，生卒年不詳，嘗學於孟子。

介然：堅固貌，有專一的意思。

為間：隔些時候。

茅塞：茅草塞住山徑。', '「茅塞」是指山徑少人走，叢生的茅草塞住了山徑，語出《孟子．盡心下》。在這章中，孟子認為一個人如果為學不能專心有恆，那就會像山間的小路一樣，常常走動，就會變成一條大路。但如果隔一些時間沒有人走，茅草就會阻塞山路。意思是說，聖人之道，要學而時習，不可捨而不修，否則就像茅草塞路一樣。勉勵高子要恆心向學，德業才可精進。「茅塞子之心」是指高子的心已經被茅草塞住了，後來「茅塞」一語就用來比喻「閉塞的心思」，也可以指的是疑惑。「頓開」的意思就是「豁然了悟」的意思。往往是因為受了指點，突然間想通了。所以「茅塞頓開」一語就可以用來比喻閉塞的心思，頓時豁然了悟。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=395&webMd=2&la=0', '', 'junior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('開門見山', '一開門就見到對門的山巒。比喻說話或寫文章直接了當，一開始就進入正題。※語或出宋．嚴羽《滄浪詩話．詩評》。

△「開宗明義」', '※宋．嚴羽《滄浪詩話．詩評》

太白發句，謂之開門見山。', '宋人嚴羽在他的《滄浪詩話》中評論各詩人的作品，在說到李白時寫道：「太白發句，謂之開門見山。」意思是說：李白因為個性豪放，所寫的詩常是一開頭就切入主題。而「開門見山」的意思，從字面來看，就是打開門就看見峻秀的青山，也可用來形容風景優美。像唐代劉得仁的〈青龍寺僧院詩〉有云：「此地堪終日，開門見數峰。」講的就是僧院風景，開門見青山，可以讓人流連終日，捨不得離開。宋代戴復古也有「瀟瀟灑灑屋三間，日日開門見好山」的詩句，形容友人蔡仲卿的青在堂景致宜人。明代的張岱有篇〈快園記〉，描述快園的景色：「開門見山，開牖見水。」也就是面對青山綠水的意思。因為推開門就能看到對門的山，所以引申出「直接了當」的意思；後來「開門見山」多被用來比喻說話或寫文章直接了當，一開始就進入正題。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=170&webMd=2&la=0', '', 'junior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('山明水秀', '形容山水秀麗，風景優美。宋．黃庭堅〈驀山溪．鴛鴦翡翠〉詞：「眉黛斂秋波，儘湖南、山明水秀。」《水滸傳》第五回：「正行之間，貪看山明水秀，不覺天色已晚。」也作「山清水秀」、「水秀山明」。', '', '', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=9960&webMd=2&la=0', '', 'junior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('學以致用', '將學得的知識運用到實際生活或工作當中。如：「光讀死書是沒有意義的，要能學以致用才是學習的真諦。」', '', '', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=8523&webMd=2&la=0', '', 'junior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('用武之地', '人雖有才能，卻無施展的機會。語本《三國志．卷三五．蜀書．諸葛亮傳》。

△「懷才不遇」', '《三國志．卷三五．蜀書．諸葛亮傳》

先主至於夏口。亮曰：「事急矣，請奉命求救於孫將軍。」時權擁軍在柴桑，觀望成敗，亮說權曰：「海內大亂，將軍起兵，據有江東，劉豫州亦收眾漢南，與曹操並爭天下。今操1>芟夷大難2>，略已平矣，遂破荊州3>，威震四海。英雄無所用武，故豫州4>遁逃至此。將軍量力而處之：若能以吳、越5>之眾，與中國6>抗衡，不如早與之絕；若不能當7>，何不案兵8>束甲，北面9>而事之！今將軍外託服從之名，而內懷猶豫之計，事急而不斷，禍至無日矣！」權曰：「苟如君言，劉豫州何不遂事之乎？」亮曰：「田橫，齊之壯士耳，猶守義不辱，況劉豫州王室之冑，英才蓋世，眾士慕仰，若水之歸海，若事之不濟，此乃天也，安能復為之下乎！」權勃然曰：「吾不能舉全吳之地，十萬之眾，受制於人。吾計決矣！非劉豫州莫可以當曹操者，然豫州新敗之後，安能抗此難乎？」亮曰：「豫州軍雖敗於長阪，今戰士還者及關羽水軍精甲萬人，劉琦合江夏戰士亦不下萬人。曹操之眾，遠來疲弊，聞追豫州，輕騎一日一夜行三百餘里，此所謂『彊弩之末，勢不能穿魯縞』者也，故兵法忌之，曰『必蹶上將軍』，且北方之人，不習水戰；又荊州之民附操者，偪兵勢耳，非心服也。今將軍誠能命猛將統兵數萬，與豫州協規同力，破操軍必矣。操軍破，必北還，如此則荊、吳之勢彊，鼎足之形成矣。成敗之機，在於今日。」權大悅，即遣周瑜、程普、魯肅等水軍三萬，隨亮詣先主，并力拒曹公。
〔注解〕

操：曹操（西元１５５∼２２０），字孟德，小字阿瞞，東漢沛國譙（今安徽省亳縣）人。有雄才，多權詐，能文學。起兵擊黃巾，討董卓，漸次剪削諸雄，自為丞相，拜大將軍，爵魏公，旋進爵魏王，加九錫。後卒於洛陽，子丕篡漢。追諡武帝，廟號太祖。

芟夷大難：戡除亂賊。芟，音ㄕㄢ。

荊州：漢所置的十三刺史部之一。地處長江中游，三國至南北朝時代是政治、軍事的重地。轄地約今湖北湖南兩省及河南省西南部。

豫州：指劉備（西元１６１∼２２３），字玄德，河北涿縣人，漢景帝之子中山靖王劉勝的後代，為三國蜀漢開國君王。東漢靈帝末年，討黃巾賊有功，遂為安喜縣尉。密誅曹操不成，潛逃。三顧茅廬始得諸葛亮輔佐。後與孫權聯合大敗曹操於赤壁，取得益州與漢中，自立為漢中王。西元二二一年，於成都即位稱帝，國號漢，年號建章。伐東吳兵敗，損失慘重，退回白帝城，因病崩逝，享年六十二，諡號「昭烈帝」，史稱為「劉先主」。

吳、越：今江蘇省、浙江省之地。

中國：上古時代，漢族文化發源黃河流域，以為居天下之中，故稱其地為「中國」。後各朝疆土漸廣，凡所轄境，皆稱為「中國」。此指東漢。

當：通「擋」，音ㄉㄤˇ，匹敵、抵抗。

案兵：止兵不動。

北面：古時臣子面向北方朝見天子，故以北面代替臣子的地位。此指向曹操稱臣。', '一個英雄身負高強武藝，卻沒有可以施展的地方，自然是相當鬱悶不得志，所以「英雄無用武之地」便是形容一個人雖有才能，卻沒有施展的機會。《三國志．卷三五．蜀書．諸葛亮傳》記載了諸葛亮於赤壁之戰前遊說孫權的經過。當時曹派大軍南下，攻下荊州，逼近東吳，情勢危急，諸葛亮請求孫權出兵，與劉備合作，共同抵禦曹軍。言談中，諸葛亮說劉備兵敗逃亡，雖是英雄，但迫於形勢，使得才能抱負無法施展，正是「英雄無用武之地」。「英雄無用武之地」多用於慨嘆，可以自嘆，也可以嘆人或物。例如：「我的專長雖是籃球，但只要隊友不能合作，也就英雄無用武之地了。」此是自嘆。至於嘆人、嘆物，後列「用法說明」諸「例句」，皆屬之，可以參看。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1208&webMd=2&la=0', '', 'junior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('地久天長', '義參「天長地久」。見「天長地久」條。', '此處所列為「天長地久」之典源，提供參考。
《老子》第七章

天長地久。天地所以能長且久者，以其不自生，故能長久。是以聖人後其身而身先，外其身而身存。以其無私，故能成其私。', '此處所列為「天長地久」之典故說明，提供參考。
老子，姓李，名耳，字聃，春秋楚國人，曾任周朝守藏室之史，後世以為道家始祖。著有《老子》一書，書中闡述道、德的意義，故又稱《道德經》。全書五千多字，內容廣泛，由養生修身，乃至治國用兵，均有極為精闢的論述，為先秦諸子中道家的代表著作。老子思想主張無為而治、天人合一、清靜寡欲。在《老子》第七章中，提到天和地會永恆無窮的存在著。天地之所以能長久存在，是因為不為自己的生存而自然地運行著，所以能夠永久長存。因此，有道的聖人遇事謙退無爭，以眾人事物為優先，把自己放在最後，反而能獲得眾人的愛戴，走在眾人的前面；將自己置於度外，不以自身為意，所以能保全自身的生存，這是因為聖人能無私，所以可成就自己。老子認為「天地」是客觀存在的自然，是「道」所生，並依「道」的規律而運行。此處老子讚美天地的長久不絕，同時以天道推及人道，希望人道能效法天道，切實仿效天地的無私無為，才能成就自身。後來原文中的「天長地久」被摘出，成為一句成語，用來形容時間的長久無止盡。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=78654&webMd=2&la=0', '', 'junior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('長驅直入', '長距離一路挺進，毫無阻擋。語本《漢書．卷五二．竇田灌韓傳．韓安國》。', '《漢書．卷五二．竇田灌韓傳．韓安國》

匈奴來請和親，上下其議。……恢曰：「不然。臣聞鳳鳥乘於風，聖人因於時。昔秦繆公都雍，地方三百里，知時宜之變，攻取西戎，辟地千里，并國十四，隴西、北地是也。及後蒙恬為秦侵胡，辟數千里，以河為竟，累石為城，樹榆為塞，匈奴不敢飲馬於河，置烽燧，然後敢牧馬。夫匈奴獨可以威服，不可以仁畜也。今以中國之盛，萬倍之資，遣百分之一以攻匈奴，譬猶以彊弩射且潰之癰也，必不留行矣。若是，則北發月氏可得而臣也。臣故曰擊之便。」安國曰：「不然。臣聞用兵者以飽待饑，正治以待其亂，定舍以待其勞，故接兵覆眾，伐國墮城，常坐而役敵國，此聖人之兵也。且臣聞之，衝風之衰，不能起毛羽；彊弩之末1>，力不能入魯縞2>。夫盛之有衰，猶朝3>之必莫4>也。今將卷甲輕舉，深入長敺，難以為功；從行則迫脅，衡行則中絕，疾則糧乏，徐則後利，不至千里，人馬乏食。兵法曰：『遺人獲也。』意者有它繆巧可以禽之，則臣不知也；不然，則未見深入之利也。臣故曰勿擊便。」
〔注解〕

彊弩之末：強弩射出的箭，到射程盡頭，已經沒有力道。比喻原本強大的力量已經衰竭，不能再發揮效用。見「強弩之末」。

縞：音ㄍㄠˇ，白色的絲織品。

朝：音ㄓㄠ，白天。

莫：音ㄇㄨˋ，同「暮」，傍晚、太陽將落的時候。', '「長驅」是長距離地一路挺進，毫無阻礙。「直入」是毫無阻擋，直接進入的意思。典源《漢書．韓安國傳》之「深入長敺」，義與「長驅直入」相近。「敺」，音ㄑㄩ，同「驅」。韓安國是西漢時的著名政治家，七國之亂時，梁孝王拜韓安國為將，統帥梁國兵馬，平息了叛亂，此後韓安國威名傳播四方。後被景帝任為梁國內史，武帝時任北地都尉，後任御史大夫。當時匈奴派遣使者來和議，朝廷大臣分成主戰跟主和兩派。主戰者認為漢朝如今國勢強大，只需派遣少量兵馬，就可以輕易消滅匈奴，所以主張將匈奴趕盡殺絕。韓安國則極力反對，他認為︰疾風一旦衰弱了，連捲起羽毛那麼輕的東西都沒辦法；強弩射出的箭到了盡頭，連魯縞那樣薄的東西都射不穿。今日如果輕舉兵馬，迅速進入敵人的勢力範圍內，後援無以為繼，必然難以收到功效，反而沒有多久就會因為缺乏糧食，而被敵軍消滅。在韓安國的斡旋之下，漢朝決定與匈奴和親，讓北方邊疆維持了多年的和平。後來這句成語就從這裡演變而出，用來形容長距離一路挺進，毫無阻擋。也等於是軍強兵盛，戰事順利的意思。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1241&webMd=2&la=0', '', 'senior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('入木三分', '指墨跡深透木板三分，形容筆力遒勁。＃語出南朝宋．羊欣《筆陣圖》。後用「入木三分」比喻評論深刻中肯或描寫生動逼真。

△「鞭辟入裡」', '＃南朝宋．羊欣《筆陣圖》（據唐．張懷瓘《書斷．卷二．王羲之》引）1>

晉2>帝時，祭北郊，更3>祝版4>。工人削之，筆入木三分。三十三，書〈蘭亭序〉；三十七，書〈黃庭經〉。書訖，空中有語：「卿書感我，而況人乎！吾是天臺丈人。」自言真勝鍾繇，羲之書多不一體。
〔注解〕

典故或見於唐．李冗《獨異志》卷上。

晉：朝代名，西元２６５∼４２０。司馬炎篡魏，吞併吳、蜀而有天下，國號晉，是為晉武帝。傳至愍帝，為前趙所滅，史稱西晉（西元２６５∼３１６）。後司馬睿即位於建康，是為晉元帝，史稱東晉（西元３１７∼４２０）。傳至恭帝，為劉裕所篡。此處所指應為東晉。

更：改。

祝版：古代祭祀所使用，寫有祭文的木版。

〔參考資料〕
唐．李冗《獨異志》卷上

王獻之常為寫〈祭晉元帝廟祝文〉版，墨入木，深八分。', '王羲之，字逸少，東晉會稽人，曾經擔任右軍將軍，因此又稱為「王右軍」。他是古代著名的書法家，擅長行、草和楷書。一般而言，秀麗的字體會顯得柔弱無力，而蒼勁挺拔的字，又常會顯得厚重剛硬，然而王羲之所寫的字，卻是風格超凡，剛柔並濟，蒼勁豪邁中不失秀麗細緻。經過勤學苦練，筆力更是強健有力，無人能比。據說，有一次皇帝在北郊舉行祭祀的儀式，必須更換原本已寫有祝祭文的木版，工人們在削去王羲之寫過的木版時，發現他的筆跡竟然透入木版有三分之深！由此可見王羲之雄厚強勁的筆力。此事見於南朝宋．羊欣《筆陣圖》。王羲之在三十三歲時寫的〈蘭亭集序〉，以及三十七歲時寫的〈黃庭經〉，一向被譽為書法藝術中最好的小楷範本，後人尊稱他為「書聖」。而羊欣用來形容王羲之筆力的「入木三分」，後來演變為成語，用來比喻評論深刻中肯或描寫生動逼真。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=58&webMd=2&la=0', '', 'senior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('分秒必爭', '一分一秒也要爭取。謂充分利用一切時間。如：「聯考在即，分秒必爭，片刻都不可放鬆。」', '', '', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=11556&webMd=2&la=0', '', 'senior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('爭先恐後', '「爭先」，爭著在前。語出《左傳．襄公二十七年》。「恐後」，惟恐落於他人之後。語本《漢書．卷一四．諸侯王表》。「爭先恐後」指競相爭先，惟恐落後。', '「爭先」：《左傳．襄公二十七年》

晉1>、楚2>爭先3>。晉人曰：「晉固為諸侯盟主，未有先晉者也。」楚人曰：「子言晉、楚匹也，若晉常先，是楚弱也。且晉、楚狎4>主諸侯之盟也久矣！豈專在晉？」叔向謂趙孟曰：「諸侯歸晉之德只，非歸其尸盟也。子務德，無爭先！且諸侯盟，小國固必有尸盟者，楚為晉細，不亦可乎？」乃先楚人。
〔注解〕

晉：周代諸侯國。春秋時據有今山西省大部分與河北省西南地區，地跨黃河兩岸。後為韓､趙､魏三家所分，遂亡。

楚：國名。周成王封熊繹於楚，春秋時稱王，為戰國七雄之一。領有今湖南、湖北、安徽、浙江及河南南部，後為秦所滅。

爭先：爭執於歃血盟誓的先後。

狎：音ㄒㄧㄚˊ，更也，交換。

「恐後」：《漢書．卷一四．諸侯王表》

王莽知漢中外殫微，本末俱弱，亡所忌憚，生其姦心；因母后之權，假伊周之稱，顓作威福廟堂之上，不降階序而運天下。詐謀既成，遂據南面之尊，分遣五威之吏，馳傳天下，班行符命。漢諸侯王厥角稽首1>，奉上璽韍2>，惟恐在後，或乃稱美頌德，以求容媚，豈不哀哉！是以究其終始彊弱之變，明監戒焉。
〔注解〕

厥角稽首：叩頭時，以額頭觸地，即一種俯首至地的最敬禮。稽，音ㄑㄧˇ。

璽韍：整組印璽。韍，音ㄈㄨˊ。', '「爭先恐後」係由「爭先」及「恐後」二語組合而成。

「爭先」是出自《左傳．襄公二十七年》，提到晉國與楚國爭執於歃血盟誓的先後。晉國人認為：晉國一向是諸侯的盟主，從來沒有其他國家在晉國之前歃血的。楚國人認為：晉國和楚國的地位是對等的，如果讓晉國一直在先，這就是楚國比晉國弱小了。而且晉國、楚國交換著主持諸侯的結盟已有很長一段時間了，怎能說晉國一直是盟主呢？因雙方爭執不下，於是叔向對趙孟（二人均為晉國臣子）說：「諸侯是歸服於晉國的德行，不是歸服於晉國是否主持盟會。你致力於修明德行，不要去爭搶歃血的先後。諸侯結盟，小國本就應有一個出來負責結盟諸種事物的，此次就讓楚國做為晉國的小國，不也可以嗎？」因此就讓楚國先歃血。

「恐後」是出自於《漢書．卷一四．諸侯王表》，內容是說王莽在西漢末年時，已察知漢朝即將走到盡頭，國力衰微，因而心生貪念，以外戚的權勢，作威作福，行使命令。其他的諸侯王看到這樣的局勢，都紛紛向王莽致上最敬禮，爭相奉上印璽，惟恐落於他人之後，有的則歌頌王莽的功德，極盡諂媚，真是令人感到悲哀！後來這兩個典源被合用成「爭先恐後」，指競相爭先，惟恐落後。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1160&webMd=2&la=0', '', 'senior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('後生可畏', '比喻年輕人的成就超越先輩，令人敬畏。語出《論語．子罕》。', '《論語．子罕》

子曰：「後生可畏，焉1>知來者之不如今也？四十、五十而無聞2>焉，斯亦不足畏也已。」
〔注解〕

焉：發問詞，怎麼。

聞：名望、成就。', '孔子是春秋的賢人，於魯國從政時，魯國大治。後因政治理念與國君不合，周遊列國十三年，卻未受到其他國君的重用。晚年返回魯國，致力於古代典籍的整理。孔子秉持「有教無類」的精神，開平民教育的先河，門下有弟子三千人。孔門後學記錄孔子應答弟子、時人以及弟子間的問答之語，而成《論語》一書，其中可見孔子思想的脈絡，以及他的治學方式。由於孔子一生在政治上未能施展抱負，所以他對門下弟子的期許極大。在〈子罕〉篇中，孔子便說：「不可以小看年輕人啊！我們怎麼知道他們將來的成就，不會超過我們這一輩呢？如果一個人到了四、五十歲，還沒有任何可以稱道的成就，那他也不會有什麼了不起的作為。」一方面表現出孔子對年輕人的無窮期待，一方面也是警惕和勉勵年長者，如果只會倚老賣老而不肯努力，就會被後生晚輩趕上。後來「後生可畏」演變為成語，用來比喻年輕人的成就超越先輩，令人敬畏。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=465&webMd=2&la=0', '', 'senior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_entries (phrase, definition, source_text, story, source_url, illustration_url, stage, license_version)
values ('畏首畏尾', '前也畏懼，後也畏懼。語出《左傳．文公十七年》。後用「畏首畏尾」形容疑慮顧忌，膽小怕事。

△「左顧右盼」、「鹿死不擇音」、「鋌而走險」', '《左傳．文公十七年》

晉侯不見鄭伯，以為貳於楚也。鄭子家使執訊而與之書，以告趙宣子，曰：「寡君即位三年，……十五年五月，陳侯自敝邑往朝于君。往年正月，燭之武往朝夷也。八月，寡君又往朝。以陳、蔡之密邇於楚而不敢貳焉，則敝邑之故也。雖敝邑之事君，何以不免？在位之中，一朝于襄，而再見于君。夷與孤之二三臣相及於絳，雖我小國，則蔑以過之矣。今大國曰：『爾未逞1>吾志。』敝邑有亡2>，無以加焉。古人有言曰：『畏首畏尾，身其餘幾？』又曰：『鹿死不擇音3>。』小國之事4>大國也，德，則5>其人也；不德，則其鹿也，鋌而走險6>，急何能擇？命之罔極，亦知亡矣……。」
〔注解〕

逞：滿足。

亡：音ㄨㄤˊ，滅亡。

鹿死不擇音：此句指鄭國如果再受晉國威逼，也許會投靠別國。就像被獵人追趕著的鹿一樣，為了活命，匆忙中就不選擇庇護之所。音，通「蔭」。

事：侍奉。

則：效法。

鋌而走險：在窮途末路或受逼迫時採取冒險行動或不正當的行為。見「鋌而走險」。', '據《左傳．文公十七年》載，在春秋時代晉、楚兩國爭相當諸侯的盟主，有一次晉國大會諸侯，卻不見鄭國來參加，因此懷疑鄭國有二心。鄭國國君於是寫了一封信給晉國國君說：我國雖小，但三年來多次朝見晉君，盡了最大的誠意，但是你們還是懷疑我們的忠誠，那麼只有走上亡國的下場了。現在我國的處境是前頭也怕，後頭也怕。既害怕楚國來攻，又擔心晉國來犯，當我們被逼得走投無路時，就像被獵人追捕的鹿一樣，為了逃命，匆忙之間，無法審慎選擇庇護之所。如果晉國過分威逼，鄭國在窮途末路之餘，即使會走上滅亡的下場，也會用全副兵力抗晉，或倒向楚國。後來「畏首畏尾」演變為成語，用來形容疑慮顧忌，膽小怕事。', 'https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=186&webMd=2&la=0', '', 'senior', 'dict_idioms_2020_20260929')
on conflict (phrase) do update set
  definition = excluded.definition, source_text = excluded.source_text, story = excluded.story,
  source_url = excluded.source_url, stage = excluded.stage, license_version = excluded.license_version,
  is_active = true, updated_at = now();

insert into public.idiom_word_grid_puzzles (title, published_on, difficulty, puzzle_data, source_version, illustration_url, is_daily_eligible, status)
values ('同心協力', '2026-10-31'::date, 'beginner', '{"board":{"width":5,"height":7,"cells":[{"key":"0:0","row":0,"column":0,"solution":"一","idiomIds":["moe-1324"],"isIntersection":false},{"key":"0:1","row":0,"column":1,"solution":"心","idiomIds":["moe-1097","moe-1324"],"isIntersection":true},{"key":"0:2","row":0,"column":2,"solution":"一","idiomIds":["moe-1324"],"isIntersection":false},{"key":"0:3","row":0,"column":3,"solution":"意","idiomIds":["moe-1324"],"isIntersection":false},{"key":"1:1","row":1,"column":1,"solution":"平","idiomIds":["moe-1097"],"isIntersection":false},{"key":"2:1","row":2,"column":1,"solution":"氣","idiomIds":["moe-1097"],"isIntersection":false},{"key":"3:1","row":3,"column":1,"solution":"和","idiomIds":["moe-10108","moe-1097"],"isIntersection":true},{"key":"3:2","row":3,"column":2,"solution":"氣","idiomIds":["moe-10108"],"isIntersection":false},{"key":"3:3","row":3,"column":3,"solution":"生","idiomIds":["moe-10108","moe-7802"],"isIntersection":true},{"key":"3:4","row":3,"column":4,"solution":"財","idiomIds":["moe-10108"],"isIntersection":false},{"key":"4:3","row":4,"column":3,"solution":"財","idiomIds":["moe-7802"],"isIntersection":false},{"key":"5:3","row":5,"column":3,"solution":"有","idiomIds":["moe-7802"],"isIntersection":false},{"key":"6:3","row":6,"column":3,"solution":"道","idiomIds":["moe-7802"],"isIntersection":false}],"placements":[{"phrase":"和氣生財","row":3,"column":1,"direction":"across","idiomId":"moe-10108"},{"phrase":"生財有道","row":3,"column":3,"direction":"down","idiomId":"moe-7802"},{"phrase":"心平氣和","row":0,"column":1,"direction":"down","idiomId":"moe-1097"},{"phrase":"一心一意","row":0,"column":0,"direction":"across","idiomId":"moe-1324"}],"omitted":[]},"idioms":[{"id":"moe-1324","phrase":"一心一意","definition":"同心同意。亦用於指心意專一，毫無他念。＃語本《杜氏新書》。\n\n△「全心全意」","source":"＃《杜氏新書》（據《三國志．卷一六．魏書．杜畿傳》裴松之注引）1>\n\n喜欲恕折節謝己，諷司馬宋權示之以微意。恕答權書曰：「況示委曲。夫法天下事，以善意相待，無不致快也；以不善意相待，無不致嫌隙也。而議者言，凡人天性皆不善，不當待以善意，更墮其調中。僕得此輩，便欲歸蹈滄海乘桴耳，不能自諧在其間也。然以年五十二，不見廢棄，頗亦遭明達君子亮其本心；若不見亮，使人刳心著地，正與數斤肉相似，何足有所明，故終不自解說。程征北功名宿著，在僕前甚多，有人出征北乎！若令下官事無大小，咨2>而後行，則非上司彈繩3>之意；若咨而不從，又非上下相順之宜。故推一心，任一意，直而行之耳。殺胡之事，天下謂之是邪，是僕諧也；呼為非邪，僕自受之，無所怨咎。程征北明之亦善，不明之亦善，諸君子自共為其心耳，不在僕言也。」喜於是遂深文劾恕。\n〔注解〕\n\n典故或見於唐．駱賓王〈代女道士王靈妃贈道士李榮〉詩。\n\n咨：徵詢；商量。\n\n彈繩：木匠彈繩墨以取直。比喻定下準則。\n\n〔參考資料〕\n唐．駱賓王〈代女道士王靈妃贈道士李榮〉詩（據《全唐詩．卷七七．駱賓王》引）\n\n寄語天上弄機人，寄語河邊值查客。乍可匆匆共百年，誰使遙遙期七夕。想知人意自相尋，果得深心共一心。一心一意無窮已，投漆投膠非足擬。","story":"「一心一意」出自於《三國志》裴松之注引《杜氏新書》。其中記載，三國時魏國大臣杜恕在寫給上司宋權的一封信中說到：「若令下官事無大小，咨而後行，則非上司彈繩之意；若咨而不從，又非上下相順之宜。故推一心，任一意，直而行之耳。」意思是自己雖為下屬，但如果做任何事都要先問過上司，那麼上司訂定的原則就沒有意義了；假使問了又不能按照上司的決定去做，也是不應該。所以在很多事上，就自己作主了。其中「推一心，任一意」是指揣測上司的想法，與上司同心。「一心一意」就表示同心同意的意思，如《二刻拍案驚奇》卷三六：「他不拘一文二文，常自喜不吝捨。他妻子見慣了的，況是女流，愈加信佛，也自與他一心一意，雖是生意淺薄，不多大事，沒有一日不捨兩文的。」「一」也有專注的意思，因此後世也用「一心一意」表示心意專一之意。如唐．駱賓王〈代女道士王靈妃贈道士李榮〉詩：「一心一意無窮已，投漆投膠非足擬。」指兩人的情感濃厚、專一，無窮無盡，用如膠似漆都無法形容。後來「一心一意」這個成語就從「推一心，任一意」演變而出，被用來表示同心同意或心意專一，毫無他念的意思。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1324&webMd=2&la=0","illustrationUrl":"","stage":"elementary"},{"id":"moe-1097","phrase":"心平氣和","definition":"心氣平和，不急不怒。語本《左傳．昭公二十年》。\n\n△「平心靜氣」","source":"《左傳．昭公二十年》\n\n齊侯至自田，晏子侍于遄臺，子猶馳而造焉。公曰：「唯據與我和夫！」晏子對曰：「據亦同也，焉得為和？」公曰：「和與同異乎？」對曰：「異。……先王之濟五味、和五聲也，以平其心，成其政也。聲亦如味，一氣、二體、三類、四物、五聲、六律、七音、八風、九歌，以相成也；清濁、大小、短長、疾徐，哀樂、剛柔，遲速、高下、出入、周疏，以相濟也。君子聽之，以平其心，心平德和。故《詩》曰：『德音不瑕1>。』今據不然。君所謂可，據亦曰可；君所謂否，據亦曰否。若以水濟水，誰能食之？若琴瑟之專壹，誰能聽之？同之不可也如是。」\n〔注解〕\n\n德音不瑕：德音是沒有瑕疵的。出自《詩經．豳風．狼跋》。瑕，音ㄒㄧㄚˊ，瑕疵、缺點。","story":"「心平氣和」原作「心平德和」。晏子，即晏嬰，春秋齊國人，在齊景公時任宰相，為當時的名臣。據《左傳．昭公二十年》載，有一天，景公遊獵回來，與大臣梁丘據等在遄臺飲酒作樂。當景公對人生有所感慨時，梁丘據亦在一旁附和，故景公說：「只有據與我是相和的啊！」隨侍在側的晏子不以為然，他說：「據和你不過是相同而已，那裡有相和！」景公訝異地問：「『和』跟『同』有什麼不一樣嗎？」晏子回答說：「若以烹調為例，在熬煮羹湯時，會適切地把不同佐料相混，使之味道調和，才做出美味的料理。君臣相處之道也是這樣的。當君王提出一個主張時，作為臣子的應該是從不同角度給予建言，使君王的施為更為完備，而不是一昧地附和而已。再以音樂為例，一篇好的樂章，是各種音符以不同的快慢、高低……組合在一起，互相搭配，調和出優美的音樂，使君子聽了，內心能得到平靜，德行能趨向平和。所以《詩經》說：德音是沒有瑕疵的。像梁丘據這樣只會對君王的說法同聲應合，就好像把清水加到清水裡去調味，誰會想去吃它呢？又好像琴瑟只彈一個單一的音符，誰會想去聽它呢？所以『同』是不好的啊！」此處的「心平德和」指的是心情的平靜，德行修養的平和。有此境界，人的脾氣自然會溫和不暴躁，所以後來由此演變成「心平氣和」這句成語，形容心氣平和，不急不怒。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1097&webMd=2&la=0","illustrationUrl":"","stage":"elementary"},{"id":"moe-10108","phrase":"和氣生財","definition":"生意人的口頭語，意指態度溫和而不得罪顧客，才會致富。如：「做生意講求和氣生財，盡心服務客人，不與客人起無謂的爭執。」","source":"","story":"","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=10108&webMd=2&la=0","illustrationUrl":"","stage":"elementary"},{"id":"moe-7802","phrase":"生財有道","definition":"語本《禮記．大學》：「生財有大道。」形容擅長發財致富。元．錢霖〈哨遍．試把賢愚窮究套．五煞〉：「乾生受，生財有道，受用無由。」","source":"","story":"","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=7802&webMd=2&la=0","illustrationUrl":"","stage":"elementary"}],"givenCellKeys":["0:0","1:1","3:2","4:3","0:2","2:1","0:3"]}'::jsonb, 'dict_idioms_2020_20260929', '', true, 'published')
on conflict (title, published_on) do update set
  difficulty = excluded.difficulty, puzzle_data = excluded.puzzle_data, source_version = excluded.source_version,
  is_daily_eligible = true, status = 'published', updated_at = now();

insert into public.idiom_word_grid_puzzles (title, published_on, difficulty, puzzle_data, source_version, illustration_url, is_daily_eligible, status)
values ('明辨與成長', '2026-10-30'::date, 'basic', '{"board":{"width":6,"height":8,"cells":[{"key":"0:0","row":0,"column":0,"solution":"自","idiomIds":["moe-89"],"isIntersection":false},{"key":"1:0","row":1,"column":0,"solution":"相","idiomIds":["moe-1325","moe-89"],"isIntersection":true},{"key":"1:1","row":1,"column":1,"solution":"得","idiomIds":["moe-1325"],"isIntersection":false},{"key":"1:2","row":1,"column":2,"solution":"益","idiomIds":["moe-1325","moe-78494"],"isIntersection":true},{"key":"1:3","row":1,"column":3,"solution":"彰","idiomIds":["moe-1325"],"isIntersection":false},{"key":"2:0","row":2,"column":0,"solution":"矛","idiomIds":["moe-89"],"isIntersection":false},{"key":"2:2","row":2,"column":2,"solution":"壽","idiomIds":["moe-78494"],"isIntersection":false},{"key":"3:0","row":3,"column":0,"solution":"盾","idiomIds":["moe-89"],"isIntersection":false},{"key":"3:2","row":3,"column":2,"solution":"延","idiomIds":["moe-78494"],"isIntersection":false},{"key":"4:2","row":4,"column":2,"solution":"年","idiomIds":["moe-78494","moe-6787"],"isIntersection":true},{"key":"4:3","row":4,"column":3,"solution":"富","idiomIds":["moe-6787"],"isIntersection":false},{"key":"4:4","row":4,"column":4,"solution":"力","idiomIds":["moe-6787"],"isIntersection":false},{"key":"4:5","row":4,"column":5,"solution":"強","idiomIds":["moe-6787","moe-227"],"isIntersection":true},{"key":"5:5","row":5,"column":5,"solution":"詞","idiomIds":["moe-227"],"isIntersection":false},{"key":"6:5","row":6,"column":5,"solution":"奪","idiomIds":["moe-227"],"isIntersection":false},{"key":"7:5","row":7,"column":5,"solution":"理","idiomIds":["moe-227"],"isIntersection":false}],"placements":[{"phrase":"相得益彰","row":1,"column":0,"direction":"across","idiomId":"moe-1325"},{"phrase":"自相矛盾","row":0,"column":0,"direction":"down","idiomId":"moe-89"},{"phrase":"益壽延年","row":1,"column":2,"direction":"down","idiomId":"moe-78494"},{"phrase":"年富力強","row":4,"column":2,"direction":"across","idiomId":"moe-6787"},{"phrase":"強詞奪理","row":4,"column":5,"direction":"down","idiomId":"moe-227"}],"omitted":[]},"idioms":[{"id":"moe-89","phrase":"自相矛盾","definition":"比喻言語或行事前後無法呼應，互相牴觸。◎典出《韓非子．難一》。","source":"《韓非子．難一》\n\n楚1>人有鬻2>楯3>與矛者，譽之曰：「吾楯之堅，物莫能陷4>也。」又譽其矛曰：「吾矛之利，於物無不陷也。」或曰：「以子之矛，陷子之楯，何如？」其人弗能應5>也。夫不可陷之楯，與無不陷之矛，不可同世而立。今堯、舜之不可兩譽，矛楯之說也。\n〔注解〕\n\n楚：國名，周成王封熊繹於楚，春秋時稱王，為戰國七雄之一，領有今湖南、湖北、安徽、浙江及河南南部，後為秦所滅。\n\n鬻：音ㄩˋ，賣。\n\n楯：音ㄕㄨㄣˇ，通「盾」。古代用來抵禦敵人兵刃及保護自己的兵器。\n\n陷：指刺入。\n\n弗能應：無法回答。\n\n兩譽：堯、舜兩人同時都得到最高的讚美。\n\n《韓非子．難勢》\n\n客曰：「人有鬻矛與楯者，譽其楯之堅，物莫能陷也。俄而又譽其矛曰：『吾矛之利，物無不陷也。』人應之曰：『以子之矛，陷子之楯，何如？』其人弗能應也。」","story":"矛是攻擊的兵器，而盾是用來防禦兵器攻擊的器具。在《韓非子．難一》中，舉了一個故事說：有個楚國人在市集上賣矛和盾。剛開始時先是誇讚他的盾說：「我這面盾非常堅固，任何鋒利的東西都刺不破它。」過了一會兒，又誇讚他的矛說：「我這隻矛是最鋒利的，沒有什麼東西是它不能刺破的。」這時，有人緊接著問說：「如果用你的矛刺你的盾，那結果會是怎樣呢？」這一問，讓賣矛與盾的人無言以對。典源又見《韓非子．難勢》。後來這個故事被濃縮成「自相矛盾」，用來比喻言語或行事前後無法呼應，互相牴觸。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=89&webMd=2&la=0","illustrationUrl":"","stage":"elementary"},{"id":"moe-1325","phrase":"相得益彰","definition":"「相得益彰」之「彰」，典源作「章」。指互相配合、映襯，更能顯出各自的優點。語本漢．王襃〈聖主得賢臣頌〉。\n\n△「相映成趣」、「聚精會神」","source":"漢．王襃〈聖主得賢臣頌〉（據《漢書．卷六四下．嚴朱吾丘主父徐嚴終王賈傳．王襃》引）\n\n昔賢者之未遭遇也，圖事揆策則君不用其謀，陳見悃誠則上不然其信，進仕不得施效，斥逐又非其愆。是故伊尹勤於鼎俎，太公困於鼓刀，百里自鬻，甯子飯牛，離此患也。及其遇明君遭聖主也，運籌合上意，諫諍即見聽，進退得關其忠，任職得行其術，去卑辱奧渫而升本朝，離疏釋蹻而享膏粱，剖符錫壤而光祖考，傳之子孫，以資說士。故世必有聖知之君，而後有賢明之臣。故虎嘯而（冽風）［風冽〕，龍興而致雲，蟋蟀俟秋唫，蜉蝤出以陰。《易》曰：「飛龍在天，利見大人。」《詩》曰：「思皇多士，生此王國。」故世平主聖，俊艾1>將自至，若堯、舜、禹、湯、文、武2>之君，獲稷3>、契4>、皋陶5>、伊尹6>、呂望7>，明明8>在朝，穆穆9>列布10>，聚精會神11>，相得益章。雖伯牙操遞鍾，逢門子彎烏號，猶未足以喻其意也。\n〔注解〕\n\n俊艾：賢德之人。艾，通「乂」，音一ˋ，才德出眾。\n\n堯、舜、禹、湯、文、武：指唐堯、虞舜、夏禹、商湯、周文王及周武王六個聖主。\n\n稷：后稷，周朝的先祖，生卒年不詳。相傳姜原因為踏到天帝的足跡，而懷了后稷。生下孩子後，最初想要將他丟棄，因此取名為棄。長大後，帝堯舉薦他為農師，因有功績，被封於邰，號曰「后稷」。\n\n契：殷代始祖。高辛氏的兒子，生卒年不詳，堯時為司徒，封於商。音ㄒ一ㄝˋ。\n\n皋陶：音ㄍㄠ　一ㄠˊ，生卒年不詳。相傳為舜的臣子，掌管刑獄事務。\n\n伊尹：名摯，生卒年不詳，商初賢相。商的開國君主湯死後，繼承君位的孫子太甲無道，伊尹將他放逐到桐宮，等到太甲悔過後，再迎回復位。\n\n呂望：指周初賢臣呂尚。字子牙，東海人，生卒年不詳。本姓姜，他的先祖封於呂，所以稱為「呂尚」。周文王出外打獵時，和他相遇於渭水河邊，相談甚歡，說道：「我的太公（父親）盼望一位能輔佐周朝的人，你真的是那個人嗎？你讓我的太公盼望好久啊！」因此呂尚又號「太公望」。周文王立他為師。後佐武王擊敗商朝，封於齊，後世稱為「姜太公」。\n\n明明：明舉賢才。\n\n穆穆：威儀盛大的樣子。\n\n列布：排列分布。\n\n聚精會神：心神聚合，會集眾人的智慧。見「聚精會神」。","story":"「相得益彰」原作「相得益章」。「彰」，明顯、彰顯的意思，「相得益彰」是指彼此互相配合、映襯，更能顯出各自的長處。《漢書．卷六四下．嚴朱吾丘主父徐嚴終王賈傳．王襃》中收錄王襃的一篇文章〈聖主得賢臣頌〉。內容主要在述說聖主和賢臣之間的關係。他認為賢才是國家的工具，官員如果是賢能的人才，則不需任何的改革更張，功德自然就會普及全國。工具銳利，用的力量少，但效果卻很好。相同的道理，聖人和君子，正是聖明君主治理天下的工具，因此君王必須認真尋找賢德之人，才能夠安逸地享受天下太平。做部屬的也是如此，賢能的人一旦遇到聖明的君主，謀略合乎君主的心意，規諫的言詞受到重視，忠君之心能夠彰顯，得以擔任官職且施展抱負。所以天下太平，君主聖明，賢能的人才自然聚集，眾人心神聚合，會集大家的智慧，互相勉勵、配合，更能顯現出各自的長處。「相得益彰」這句成語就出自此處，指互相配合、映襯，更能顯出各自的優點。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1325&webMd=2&la=0","illustrationUrl":"","stage":"elementary"},{"id":"moe-78494","phrase":"益壽延年","definition":"義參「延年益壽」。見「延年益壽」條。","source":"此處所列為「延年益壽」之典源，提供參考。\n東周戰國．宋玉〈高唐賦并序〉（據《文選．卷一九．賦》引）\n\n昔者楚襄王與宋玉遊於雲夢之臺，望高唐之觀，其上獨有雲氣，崒兮直上，忽兮改容，須臾之間，變化無窮。王問玉曰：「此何氣也？」玉對曰：「所謂朝雲者也。」王曰：「何謂朝雲？」玉曰：「昔者先王嘗遊高唐，怠而晝寢，夢見一婦人曰：『妾，巫山之女也。爲高唐之客。聞君遊高唐，願薦枕席。』王因幸之。去而辭曰：『妾在巫山之陽，高丘之阻，旦為朝雲，暮為行雨。朝朝暮暮，陽臺之下。』旦朝視之，如言。故為立廟，號曰『朝雲』。」……王將欲往見，必先齋戒1>，差2>時擇日，簡輿玄服3>。建雲斾4>，蜺為旌5>，翠為蓋6>。風起雨止，千里而逝。蓋發蒙7>，往自會。思萬方，憂國害，開賢聖，輔不逮。九竅8>通鬱，精神察滯，延年益壽千萬歲。\n〔注解〕\n\n齋戒：在祭祀或舉行重要典禮之前，沐浴更衣，不飲酒，不吃葷，夫妻不同房，嚴守戒律，以示虔誠莊敬。\n\n差：音ㄔㄞ，選擇。\n\n簡輿玄服：減省車馬隨從，穿上黑色衣服。\n\n雲斾：有雲彩紋飾的大旗。斾，同「旆」，音ㄆㄟˋ。\n\n蜺為旌：裝飾著五彩羽毛的旗子。蜺，同「霓」，音ㄋ一ˊ，彩虹。\n\n翠為蓋：用翠鳥羽毛裝飾的車蓋。\n\n發蒙：啟發蒙昧。\n\n九竅：指人身上的九個孔竅，包含兩眼、兩耳、兩鼻孔、口及排尿口、肛門。","story":"此處所列為「延年益壽」之典故說明，提供參考。\n宋玉（約前２９８年—約前２２２年），為戰國後期楚國的辭賦家。他寫下了不少傳世經典的作品，譬如〈高唐賦〉、〈神女賦〉及〈登徒子好色賦〉等。〈高唐賦〉這篇作品由序及正文兩部分組成，序的部分藉著描寫楚襄王與宋玉遊於雲夢之臺，遠望高唐的景觀，看到高唐上方的雲氣千變萬化，進而帶出過去楚懷王也曾經遊覽高唐，並在夢中遇見巫山神女的情景。後面的正文則分別描述了高唐地區的山川地形景觀，首先是雨過天晴之後，百川匯聚，水勢洶湧澎湃的情狀。又山中草木繁茂雜生，風吹枝條所發出的悲鳴聲，令人動容。至於山勢險峻，岩石參差堆疊，望去又令人驚心動魄。另外還寫出仙人在高唐聚會祈禱，以及楚王奏樂田獵的盛況。整篇文章在極盡排比鋪寫後，最後才進入主題，指出楚王的心裡應該想著百姓，為國家的禍福憂心，任用賢能的人來輔助自己才能的不足。如此一來，不僅身上九竅得以暢通，精神更加清朗，壽命自然能綿延到千萬歲。後來原文中的「延年益壽」被摘出，成為一句成語，用來指拉長歲數，增加壽命。多作為頌祝人長壽的用詞。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=78494&webMd=2&la=0","illustrationUrl":"","stage":"elementary"},{"id":"moe-6787","phrase":"年富力強","definition":"正值壯年，精力旺盛，大有作為。《明史．卷六九．選舉志一》：「務求學行兼優，年富力強，累試優等者，乃以充貢。」《醒世恆言．卷二．三孝廉讓產立高名》：「二弟年富力強，方司民社，宜資莊產，以終廉節。」","source":"","story":"","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=6787&webMd=2&la=0","illustrationUrl":"","stage":"elementary"},{"id":"moe-227","phrase":"強詞奪理","definition":"「強詞奪理」之「奪」，典源作「昧」。形容沒有道理卻強為狡辯，硬說成有理。語本唐．神清《北山錄．卷三．合霸王》。","source":"唐．神清《北山錄．卷三．合霸王》\n\n三國初，吳人未甚信。天竺沙門康僧會始造於吳，締搆行道，孫權以為誣。……孫皓狂虐不道，國將病矣！初廢毀淫祠，延及寺宇，群臣議曰︰「佛之威力不並餘神，僧會感靈。太皇創寺，今若輕廢，恐貽後悔。皓意未謂之然，使張昱至寺詰會，會才辯奇拔，昱不能加，乃復于皓。皓1>大集公卿洎2>庶寮3>，徵會以車馬，既至，皓強詞昧理，取會不及已。而會酬抗盡典謨之體，推引叶忠良之議。皓然知其不可屈，乃革容而敬焉。\n〔注解〕\n\n皓：孫皓（西元２４２∼２８４），三國吳皇帝，字元宗，一名彭祖，字皓宗。孫皓個性專橫殘暴，奢侈荒淫，大失民心。天紀四年，晉武帝六路出兵攻吳，皓出降，在位十六年，後封為歸命侯。\n\n洎：音ㄐㄧˋ。到、及。\n\n庶寮：眾官。寮，同「僚」。","story":"「強詞奪理」原作「強詞昧理」。佛教約於東漢明帝時正式傳入中國，但一直僅流傳於北方，並未傳入江南。直到東漢末年，部分佛教徒為了躲避中原的戰亂，遷居吳地，佛教才隨之進入江南。據唐．神清《北山錄．卷三．合霸王》載，東吳孫權赤烏年間，天竺僧人康僧會為在江南弘法，來到建業，奉勸孫權信佛並建寺塔，顯佛骨舍利神蹟，於是孫權命人建塔十三座，自此篤信佛教。後來孫皓繼位，他暴虐無道，施行苛政，並要拆毀廟宇，褻瀆神佛。眾臣力勸不可，他們認為佛之能力跟其餘眾神不同，且佛塔是先王所建，若輕易拆毀，恐怕會遭到天譴，到時就後悔莫及了。孫皓因此猶豫不決，決定派張昱先去會見僧會，試探他的實力。張昱年輕好辯，又不信鬼神之事，向僧會提出了不少詰難。僧會雖已年老，但面對張昱的詰問仍回答得頭頭是道，使張昱無懈可擊，反被折服，只得回去向孫皓覆命。孫皓知道了僧會的辯才無礙之後，更想見他一面，於是召集了公卿百官，又派人去接僧會入宮。僧會來到宮中之後，孫皓也提出許多問題想要辯倒僧會，他問僧會說：「佛教所宣揚的是什麼道理呢？」僧會回答：「是視眾生平等。君王能夠愛民，使人民安居樂業；人民能懂孝悌仁義，互相友愛。」孫皓聽了之後又說：「這不都是孔孟的道理嗎？」僧會回答：「佛法與孔孟之道有相同之處，也有不同之處。孔孟主要傳揚人倫，這點與佛法是一樣的，但是佛法更加廣泛，提及因緣生滅、諸行無常，這則是孔孟之道所沒有的。」孫皓雖然強自狡辯，但仍無法辯倒僧會，也就不敢隨便毀壞廟宇佛像了。後來「強詞奪理」這句成語，就從這裡的原文「強詞昧理」演變而出，用來形容沒有道理卻強行狡辯，硬說成有理。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=227&webMd=2&la=0","illustrationUrl":"","stage":"elementary"}],"givenCellKeys":["0:0","1:1","2:2","4:3","5:5"]}'::jsonb, 'dict_idioms_2020_20260929', '', true, 'published')
on conflict (title, published_on) do update set
  difficulty = excluded.difficulty, puzzle_data = excluded.puzzle_data, source_version = excluded.source_version,
  is_daily_eligible = true, status = 'published', updated_at = now();

insert into public.idiom_word_grid_puzzles (title, published_on, difficulty, puzzle_data, source_version, illustration_url, is_daily_eligible, status)
values ('功成與開展', '2026-10-29'::date, 'advanced', '{"board":{"width":9,"height":9,"cells":[{"key":"0:0","row":0,"column":0,"solution":"事","idiomIds":["moe-273"],"isIntersection":false},{"key":"0:1","row":0,"column":1,"solution":"半","idiomIds":["moe-273"],"isIntersection":false},{"key":"0:2","row":0,"column":2,"solution":"功","idiomIds":["moe-15425","moe-273"],"isIntersection":true},{"key":"0:3","row":0,"column":3,"solution":"倍","idiomIds":["moe-273"],"isIntersection":false},{"key":"1:2","row":1,"column":2,"solution":"成","idiomIds":["moe-15425"],"isIntersection":false},{"key":"2:2","row":2,"column":2,"solution":"名","idiomIds":["moe-1347","moe-15425"],"isIntersection":true},{"key":"2:3","row":2,"column":3,"solution":"列","idiomIds":["moe-1347"],"isIntersection":false},{"key":"2:4","row":2,"column":4,"solution":"前","idiomIds":["moe-1347"],"isIntersection":false},{"key":"2:5","row":2,"column":5,"solution":"茅","idiomIds":["moe-1347","moe-395"],"isIntersection":true},{"key":"3:2","row":3,"column":2,"solution":"就","idiomIds":["moe-15425"],"isIntersection":false},{"key":"3:5","row":3,"column":5,"solution":"塞","idiomIds":["moe-395"],"isIntersection":false},{"key":"4:5","row":4,"column":5,"solution":"頓","idiomIds":["moe-395"],"isIntersection":false},{"key":"5:5","row":5,"column":5,"solution":"開","idiomIds":["moe-395","moe-170"],"isIntersection":true},{"key":"5:6","row":5,"column":6,"solution":"門","idiomIds":["moe-170"],"isIntersection":false},{"key":"5:7","row":5,"column":7,"solution":"見","idiomIds":["moe-170"],"isIntersection":false},{"key":"5:8","row":5,"column":8,"solution":"山","idiomIds":["moe-170","moe-9960"],"isIntersection":true},{"key":"6:8","row":6,"column":8,"solution":"明","idiomIds":["moe-9960"],"isIntersection":false},{"key":"7:8","row":7,"column":8,"solution":"水","idiomIds":["moe-9960"],"isIntersection":false},{"key":"8:8","row":8,"column":8,"solution":"秀","idiomIds":["moe-9960"],"isIntersection":false}],"placements":[{"phrase":"名列前茅","row":2,"column":2,"direction":"across","idiomId":"moe-1347"},{"phrase":"功成名就","row":0,"column":2,"direction":"down","idiomId":"moe-15425"},{"phrase":"茅塞頓開","row":2,"column":5,"direction":"down","idiomId":"moe-395"},{"phrase":"事半功倍","row":0,"column":0,"direction":"across","idiomId":"moe-273"},{"phrase":"開門見山","row":5,"column":5,"direction":"across","idiomId":"moe-170"},{"phrase":"山明水秀","row":5,"column":8,"direction":"down","idiomId":"moe-9960"}],"omitted":[]},"idioms":[{"id":"moe-273","phrase":"事半功倍","definition":"事情只用古人一半的心力，而功效加倍。形容費力少而收效大。語本《孟子．公孫丑上》。後用「事半功倍」比喻工作效率高。\n\n△「以解倒懸」、「事倍功半」、「飢不擇食」、「渴不擇飲」","source":"《孟子．公孫丑上》\n\n（孟子）曰：「文王何可當也，由湯至於武丁，賢聖之君六七作，天下歸殷久矣，久則難變也。……夏后殷周之盛，地未有過千里者也，而齊有其地矣。雞鳴狗吠相聞，而達乎四境，而齊有其民矣。地不改辟矣，民不改聚矣，行仁政而王，莫之能禦也。且王者之不作，未有疏於此時者也。民之憔悴於虐政，未有甚於此時者也。飢者易為食，渴者易為飲。孔子曰：『德之流行，速於置郵而傳命。』當今之時，萬乘之國1>行仁政，民之悅之，猶解倒懸2>也。故事半古之人，功必倍之，惟此時為然。」\n〔注解〕\n\n萬乘之國：擁有萬輛兵車的國家。指大國。乘，音ㄕㄥˋ，古代計算車輛的單位，四馬一車名乘。\n\n倒懸：縛人兩足倒掛，比喻極為困苦。","story":"戰國齊人公孫丑是孟子弟子，他曾經問孟子：「如果夫子掌握齊國大權，可以建立和管仲、晏嬰那樣的功業嗎？」孟子不願意被拿來和管仲相比，認為幫助齊國統一天下是件很容易的事。比起之前的夏、商、周三代，現今的齊國不但國土廣大，而且人民眾多，加上以王道來治理天下的聖明君主很久沒有出現，以致人民長久處在暴政之中，他們心中渴望施行仁政的程度和「肚子餓的人只求吃飽，口渴的人只求解渴」一樣。所以齊國若在此時施行仁政，將正應驗孔子說的：「德行流傳的速度，比驛馬傳達命令還快。」而人民心裡喜悅的程度，會就像脫離兩腳被綁住倒掛的困境一樣。這和古時候的人相比，只要花費一半的心力，就能達到加倍的功效。後來「事半功倍」這句成語就從這裡演變而出，用來比喻工作效率高。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=273&webMd=2&la=0","illustrationUrl":"","stage":"junior"},{"id":"moe-15425","phrase":"功成名就","definition":"事業有所成就，而且有名望。元．范康《竹葉舟》第二折：「你則說做官的功成名就，我則說出家的延年益壽。」也作「功就名成」、「功成名立」、「功成名遂」。","source":"","story":"","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=15425&webMd=2&la=0","illustrationUrl":"","stage":"junior"},{"id":"moe-1347","phrase":"名列前茅","definition":"茅，通「旄」。旄，旄牛。前茅，古代行軍打仗時，前行的兵士所拿的竿頂用旄牛尾裝飾的指揮旗幟。一說茅即茅草，春秋時代楚國行軍，有人拿著茅草當旗幟走在軍隊前面，或擔任斥候。「名列前茅」，指其名列於隊伍前面。語本《左傳．宣公十二年》。後用「名列前茅」比喻成績優異，名次排在前面。\n\n△「獨占鰲頭」","source":"《左傳．宣公十二年》\n\n夏，六月，晉師救鄭。荀林父將中軍，先縠佐之；士會將上軍，郤克佐之；趙朔將下軍，欒書佐之。趙括、趙嬰齊為中軍大夫，鞏朔、韓穿為上軍大夫，荀首、趙同為下軍大夫，韓厥為司馬。及河，聞鄭既及楚平，桓子欲還，曰：「無及於鄭而勦民，焉用之？楚歸而動，不後。」隨武子曰：「善。會聞用師，觀釁而動。德刑政事典禮不易，不可敵也，不為是征。楚軍討鄭，怒其貳而哀其卑，叛而伐之，服而舍之，德刑成矣。伐叛，刑也；柔服，德也。二者立矣。昔歲入陳，今茲入鄭，民不罷勞，君無怨讟，政有經矣。荊尸而舉，商、農、工、賈不敗其業，而卒乘輯睦，事不奸矣。蒍敖1>為宰2>，擇楚國3>之令典4>，軍行，右轅5>，左追蓐6>，前茅7>慮無8>，中權9>，後勁10>，百官象物而動11>，軍政不戒而備，能用典矣。其君之舉也，內姓選於親，外姓選於舊。舉不失德，賞不失勞。老有加惠，旅有施舍。君子小人，物有服章，貴有常尊，賤有等威，禮不逆矣。德立，刑行，政成，事時，典從，禮順，若之何敵之？見可而進，知難而退，軍之善政也。兼弱攻昧，武之善經也。子姑整軍而經武乎，猶有弱而昧者，何必楚？仲虺有言曰：『取亂侮亡。』兼弱也。〈汋〉曰：『於鑠王師，遵養時晦。』耆昧也。〈武〉曰：『無競惟烈。』撫弱耆昧以務烈所，可也。」彘子曰：「不可。晉所以霸，師武臣力也。今失諸侯，不可謂力。有敵而不從，不可謂武。由我失霸，不如死。且成師以出，聞敵彊而退，非夫也。命有軍師，而卒以非夫，唯群子能，我弗為也。」以中軍佐濟。\n〔注解〕\n\n蒍敖：孫叔敖，春秋楚人，生卒年不詳。蒍賈之子。兒時於路上見兩頭蛇，聞人言，見此蛇者必死，自以為將死，而恐後人見之又死，乃殺而埋之。及長，性恭儉，代虞丘為楚相，施教導民，三月而楚大治。彼曾三得相而不喜，三去相而不悔，不以得失為意，史稱循吏。蒍，音ㄨㄟˇ。\n\n宰：太宰，統理百官之長。\n\n楚國：周成王封熊繹於楚，春秋時稱王，為戰國七雄之一。領有今湖南、湖北、安徽、浙江及河南南部，後為秦所滅。\n\n令典：好的典章法度。\n\n轅：車前駕牲畜的兩根直木，此指跟隨在主將車轅旁備戰。\n\n追蓐：追尋可做席墊的草，割之以備用。蓐，音ㄖㄨˋ，草墊子。\n\n前茅：稱軍中的偵察敵情的哨兵，又稱「斥候」。古代斥候，以旄旌（竿頂以旄牛尾裝飾的指揮旗幟）或茅草為標幟，看到前方的敵人，則舉旌以報告在後面的軍隊戒備。\n\n慮無：戒備意外。\n\n中權：中軍制定謀略。\n\n後勁：後軍精良。\n\n象物而動：根據旌旗的指揮而行動。","story":"據《左傳．宣公十二年》載，春秋時代，楚國攻打鄭國，晉國派兵援鄭，但晉軍抵達前鄭國就已投降，晉軍統帥荀林父（ㄈㄨˇ）於是打算班師回朝。上軍主將士會支持荀林父的決定，因為他認為現在的楚國德行、刑罰、政令、事務、典章、禮儀都具備周全，根本無法與之為敵。在分析到楚國軍力時，他曾說道：「軍行，右轅，左追蓐，前茅慮無，中權，後勁。」意思是：楚國軍隊紀律嚴明，行軍之時，右軍緊隨在主將車轅旁備戰，左軍負責割草以備休息用，前軍的哨兵偵察敵情極為慎重，中軍依情報制定謀略，後軍則十分精良，整個部隊實力雄厚，難與抗衡。士會話中的「前茅」，指的便是行軍時置於最前方，負責偵察敵情的哨兵。古代作戰時，前鋒部隊是以旄旌或茅草作為識別標誌，一旦偵察到敵方位置，就舉之而告知後方軍隊加強戒備，故以「前茅」稱此負責偵察的前軍。後來「前茅」引申有排名在前的意思，而「名列前茅」則可用來比喻成績優異，名次排在前面。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1347&webMd=2&la=0","illustrationUrl":"","stage":"junior"},{"id":"moe-395","phrase":"茅塞頓開","definition":"被茅草阻塞的山路，豁然開通了。比喻閉塞的心思，頓時豁然了悟。語本《孟子．盡心下》。","source":"《孟子．盡心下》\n\n孟子謂高子1>曰：「山徑之蹊間，介然2>用之而成路；為間3>不用，則茅塞4>之矣。今茅塞子之心矣。」\n〔注解〕\n\n高子：戰國時齊人，生卒年不詳，嘗學於孟子。\n\n介然：堅固貌，有專一的意思。\n\n為間：隔些時候。\n\n茅塞：茅草塞住山徑。","story":"「茅塞」是指山徑少人走，叢生的茅草塞住了山徑，語出《孟子．盡心下》。在這章中，孟子認為一個人如果為學不能專心有恆，那就會像山間的小路一樣，常常走動，就會變成一條大路。但如果隔一些時間沒有人走，茅草就會阻塞山路。意思是說，聖人之道，要學而時習，不可捨而不修，否則就像茅草塞路一樣。勉勵高子要恆心向學，德業才可精進。「茅塞子之心」是指高子的心已經被茅草塞住了，後來「茅塞」一語就用來比喻「閉塞的心思」，也可以指的是疑惑。「頓開」的意思就是「豁然了悟」的意思。往往是因為受了指點，突然間想通了。所以「茅塞頓開」一語就可以用來比喻閉塞的心思，頓時豁然了悟。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=395&webMd=2&la=0","illustrationUrl":"","stage":"junior"},{"id":"moe-170","phrase":"開門見山","definition":"一開門就見到對門的山巒。比喻說話或寫文章直接了當，一開始就進入正題。※語或出宋．嚴羽《滄浪詩話．詩評》。\n\n△「開宗明義」","source":"※宋．嚴羽《滄浪詩話．詩評》\n\n太白發句，謂之開門見山。","story":"宋人嚴羽在他的《滄浪詩話》中評論各詩人的作品，在說到李白時寫道：「太白發句，謂之開門見山。」意思是說：李白因為個性豪放，所寫的詩常是一開頭就切入主題。而「開門見山」的意思，從字面來看，就是打開門就看見峻秀的青山，也可用來形容風景優美。像唐代劉得仁的〈青龍寺僧院詩〉有云：「此地堪終日，開門見數峰。」講的就是僧院風景，開門見青山，可以讓人流連終日，捨不得離開。宋代戴復古也有「瀟瀟灑灑屋三間，日日開門見好山」的詩句，形容友人蔡仲卿的青在堂景致宜人。明代的張岱有篇〈快園記〉，描述快園的景色：「開門見山，開牖見水。」也就是面對青山綠水的意思。因為推開門就能看到對門的山，所以引申出「直接了當」的意思；後來「開門見山」多被用來比喻說話或寫文章直接了當，一開始就進入正題。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=170&webMd=2&la=0","illustrationUrl":"","stage":"junior"},{"id":"moe-9960","phrase":"山明水秀","definition":"形容山水秀麗，風景優美。宋．黃庭堅〈驀山溪．鴛鴦翡翠〉詞：「眉黛斂秋波，儘湖南、山明水秀。」《水滸傳》第五回：「正行之間，貪看山明水秀，不覺天色已晚。」也作「山清水秀」、「水秀山明」。","source":"","story":"","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=9960&webMd=2&la=0","illustrationUrl":"","stage":"junior"}],"givenCellKeys":["0:0","1:2","2:3","3:5","5:6","6:8"]}'::jsonb, 'dict_idioms_2020_20260929', '', true, 'published')
on conflict (title, published_on) do update set
  difficulty = excluded.difficulty, puzzle_data = excluded.puzzle_data, source_version = excluded.source_version,
  is_daily_eligible = true, status = 'published', updated_at = now();

insert into public.idiom_word_grid_puzzles (title, published_on, difficulty, puzzle_data, source_version, illustration_url, is_daily_eligible, status)
values ('學以致用', '2026-10-28'::date, 'challenge', '{"board":{"width":13,"height":16,"cells":[{"key":"0:0","row":0,"column":0,"solution":"學","idiomIds":["moe-8523"],"isIntersection":false},{"key":"1:0","row":1,"column":0,"solution":"以","idiomIds":["moe-8523"],"isIntersection":false},{"key":"2:0","row":2,"column":0,"solution":"致","idiomIds":["moe-8523"],"isIntersection":false},{"key":"3:0","row":3,"column":0,"solution":"用","idiomIds":["moe-1208","moe-8523"],"isIntersection":true},{"key":"3:1","row":3,"column":1,"solution":"武","idiomIds":["moe-1208"],"isIntersection":false},{"key":"3:2","row":3,"column":2,"solution":"之","idiomIds":["moe-1208"],"isIntersection":false},{"key":"3:3","row":3,"column":3,"solution":"地","idiomIds":["moe-78654","moe-1208"],"isIntersection":true},{"key":"4:3","row":4,"column":3,"solution":"久","idiomIds":["moe-78654"],"isIntersection":false},{"key":"5:3","row":5,"column":3,"solution":"天","idiomIds":["moe-78654"],"isIntersection":false},{"key":"6:3","row":6,"column":3,"solution":"長","idiomIds":["moe-1241","moe-78654"],"isIntersection":true},{"key":"6:4","row":6,"column":4,"solution":"驅","idiomIds":["moe-1241"],"isIntersection":false},{"key":"6:5","row":6,"column":5,"solution":"直","idiomIds":["moe-1241"],"isIntersection":false},{"key":"6:6","row":6,"column":6,"solution":"入","idiomIds":["moe-58","moe-1241"],"isIntersection":true},{"key":"7:6","row":7,"column":6,"solution":"木","idiomIds":["moe-58"],"isIntersection":false},{"key":"8:6","row":8,"column":6,"solution":"三","idiomIds":["moe-58"],"isIntersection":false},{"key":"9:6","row":9,"column":6,"solution":"分","idiomIds":["moe-11556","moe-58"],"isIntersection":true},{"key":"9:7","row":9,"column":7,"solution":"秒","idiomIds":["moe-11556"],"isIntersection":false},{"key":"9:8","row":9,"column":8,"solution":"必","idiomIds":["moe-11556"],"isIntersection":false},{"key":"9:9","row":9,"column":9,"solution":"爭","idiomIds":["moe-1160","moe-11556"],"isIntersection":true},{"key":"10:9","row":10,"column":9,"solution":"先","idiomIds":["moe-1160"],"isIntersection":false},{"key":"11:9","row":11,"column":9,"solution":"恐","idiomIds":["moe-1160"],"isIntersection":false},{"key":"12:9","row":12,"column":9,"solution":"後","idiomIds":["moe-465","moe-1160"],"isIntersection":true},{"key":"12:10","row":12,"column":10,"solution":"生","idiomIds":["moe-465"],"isIntersection":false},{"key":"12:11","row":12,"column":11,"solution":"可","idiomIds":["moe-465"],"isIntersection":false},{"key":"12:12","row":12,"column":12,"solution":"畏","idiomIds":["moe-465","moe-186"],"isIntersection":true},{"key":"13:12","row":13,"column":12,"solution":"首","idiomIds":["moe-186"],"isIntersection":false},{"key":"14:12","row":14,"column":12,"solution":"畏","idiomIds":["moe-186"],"isIntersection":false},{"key":"15:12","row":15,"column":12,"solution":"尾","idiomIds":["moe-186"],"isIntersection":false}],"placements":[{"phrase":"後生可畏","row":12,"column":9,"direction":"across","idiomId":"moe-465"},{"phrase":"爭先恐後","row":9,"column":9,"direction":"down","idiomId":"moe-1160"},{"phrase":"畏首畏尾","row":12,"column":12,"direction":"down","idiomId":"moe-186"},{"phrase":"分秒必爭","row":9,"column":6,"direction":"across","idiomId":"moe-11556"},{"phrase":"入木三分","row":6,"column":6,"direction":"down","idiomId":"moe-58"},{"phrase":"長驅直入","row":6,"column":3,"direction":"across","idiomId":"moe-1241"},{"phrase":"地久天長","row":3,"column":3,"direction":"down","idiomId":"moe-78654"},{"phrase":"用武之地","row":3,"column":0,"direction":"across","idiomId":"moe-1208"},{"phrase":"學以致用","row":0,"column":0,"direction":"down","idiomId":"moe-8523"}],"omitted":[]},"idioms":[{"id":"moe-8523","phrase":"學以致用","definition":"將學得的知識運用到實際生活或工作當中。如：「光讀死書是沒有意義的，要能學以致用才是學習的真諦。」","source":"","story":"","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=8523&webMd=2&la=0","illustrationUrl":"","stage":"junior"},{"id":"moe-1208","phrase":"用武之地","definition":"人雖有才能，卻無施展的機會。語本《三國志．卷三五．蜀書．諸葛亮傳》。\n\n△「懷才不遇」","source":"《三國志．卷三五．蜀書．諸葛亮傳》\n\n先主至於夏口。亮曰：「事急矣，請奉命求救於孫將軍。」時權擁軍在柴桑，觀望成敗，亮說權曰：「海內大亂，將軍起兵，據有江東，劉豫州亦收眾漢南，與曹操並爭天下。今操1>芟夷大難2>，略已平矣，遂破荊州3>，威震四海。英雄無所用武，故豫州4>遁逃至此。將軍量力而處之：若能以吳、越5>之眾，與中國6>抗衡，不如早與之絕；若不能當7>，何不案兵8>束甲，北面9>而事之！今將軍外託服從之名，而內懷猶豫之計，事急而不斷，禍至無日矣！」權曰：「苟如君言，劉豫州何不遂事之乎？」亮曰：「田橫，齊之壯士耳，猶守義不辱，況劉豫州王室之冑，英才蓋世，眾士慕仰，若水之歸海，若事之不濟，此乃天也，安能復為之下乎！」權勃然曰：「吾不能舉全吳之地，十萬之眾，受制於人。吾計決矣！非劉豫州莫可以當曹操者，然豫州新敗之後，安能抗此難乎？」亮曰：「豫州軍雖敗於長阪，今戰士還者及關羽水軍精甲萬人，劉琦合江夏戰士亦不下萬人。曹操之眾，遠來疲弊，聞追豫州，輕騎一日一夜行三百餘里，此所謂『彊弩之末，勢不能穿魯縞』者也，故兵法忌之，曰『必蹶上將軍』，且北方之人，不習水戰；又荊州之民附操者，偪兵勢耳，非心服也。今將軍誠能命猛將統兵數萬，與豫州協規同力，破操軍必矣。操軍破，必北還，如此則荊、吳之勢彊，鼎足之形成矣。成敗之機，在於今日。」權大悅，即遣周瑜、程普、魯肅等水軍三萬，隨亮詣先主，并力拒曹公。\n〔注解〕\n\n操：曹操（西元１５５∼２２０），字孟德，小字阿瞞，東漢沛國譙（今安徽省亳縣）人。有雄才，多權詐，能文學。起兵擊黃巾，討董卓，漸次剪削諸雄，自為丞相，拜大將軍，爵魏公，旋進爵魏王，加九錫。後卒於洛陽，子丕篡漢。追諡武帝，廟號太祖。\n\n芟夷大難：戡除亂賊。芟，音ㄕㄢ。\n\n荊州：漢所置的十三刺史部之一。地處長江中游，三國至南北朝時代是政治、軍事的重地。轄地約今湖北湖南兩省及河南省西南部。\n\n豫州：指劉備（西元１６１∼２２３），字玄德，河北涿縣人，漢景帝之子中山靖王劉勝的後代，為三國蜀漢開國君王。東漢靈帝末年，討黃巾賊有功，遂為安喜縣尉。密誅曹操不成，潛逃。三顧茅廬始得諸葛亮輔佐。後與孫權聯合大敗曹操於赤壁，取得益州與漢中，自立為漢中王。西元二二一年，於成都即位稱帝，國號漢，年號建章。伐東吳兵敗，損失慘重，退回白帝城，因病崩逝，享年六十二，諡號「昭烈帝」，史稱為「劉先主」。\n\n吳、越：今江蘇省、浙江省之地。\n\n中國：上古時代，漢族文化發源黃河流域，以為居天下之中，故稱其地為「中國」。後各朝疆土漸廣，凡所轄境，皆稱為「中國」。此指東漢。\n\n當：通「擋」，音ㄉㄤˇ，匹敵、抵抗。\n\n案兵：止兵不動。\n\n北面：古時臣子面向北方朝見天子，故以北面代替臣子的地位。此指向曹操稱臣。","story":"一個英雄身負高強武藝，卻沒有可以施展的地方，自然是相當鬱悶不得志，所以「英雄無用武之地」便是形容一個人雖有才能，卻沒有施展的機會。《三國志．卷三五．蜀書．諸葛亮傳》記載了諸葛亮於赤壁之戰前遊說孫權的經過。當時曹派大軍南下，攻下荊州，逼近東吳，情勢危急，諸葛亮請求孫權出兵，與劉備合作，共同抵禦曹軍。言談中，諸葛亮說劉備兵敗逃亡，雖是英雄，但迫於形勢，使得才能抱負無法施展，正是「英雄無用武之地」。「英雄無用武之地」多用於慨嘆，可以自嘆，也可以嘆人或物。例如：「我的專長雖是籃球，但只要隊友不能合作，也就英雄無用武之地了。」此是自嘆。至於嘆人、嘆物，後列「用法說明」諸「例句」，皆屬之，可以參看。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1208&webMd=2&la=0","illustrationUrl":"","stage":"junior"},{"id":"moe-78654","phrase":"地久天長","definition":"義參「天長地久」。見「天長地久」條。","source":"此處所列為「天長地久」之典源，提供參考。\n《老子》第七章\n\n天長地久。天地所以能長且久者，以其不自生，故能長久。是以聖人後其身而身先，外其身而身存。以其無私，故能成其私。","story":"此處所列為「天長地久」之典故說明，提供參考。\n老子，姓李，名耳，字聃，春秋楚國人，曾任周朝守藏室之史，後世以為道家始祖。著有《老子》一書，書中闡述道、德的意義，故又稱《道德經》。全書五千多字，內容廣泛，由養生修身，乃至治國用兵，均有極為精闢的論述，為先秦諸子中道家的代表著作。老子思想主張無為而治、天人合一、清靜寡欲。在《老子》第七章中，提到天和地會永恆無窮的存在著。天地之所以能長久存在，是因為不為自己的生存而自然地運行著，所以能夠永久長存。因此，有道的聖人遇事謙退無爭，以眾人事物為優先，把自己放在最後，反而能獲得眾人的愛戴，走在眾人的前面；將自己置於度外，不以自身為意，所以能保全自身的生存，這是因為聖人能無私，所以可成就自己。老子認為「天地」是客觀存在的自然，是「道」所生，並依「道」的規律而運行。此處老子讚美天地的長久不絕，同時以天道推及人道，希望人道能效法天道，切實仿效天地的無私無為，才能成就自身。後來原文中的「天長地久」被摘出，成為一句成語，用來形容時間的長久無止盡。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=78654&webMd=2&la=0","illustrationUrl":"","stage":"junior"},{"id":"moe-1241","phrase":"長驅直入","definition":"長距離一路挺進，毫無阻擋。語本《漢書．卷五二．竇田灌韓傳．韓安國》。","source":"《漢書．卷五二．竇田灌韓傳．韓安國》\n\n匈奴來請和親，上下其議。……恢曰：「不然。臣聞鳳鳥乘於風，聖人因於時。昔秦繆公都雍，地方三百里，知時宜之變，攻取西戎，辟地千里，并國十四，隴西、北地是也。及後蒙恬為秦侵胡，辟數千里，以河為竟，累石為城，樹榆為塞，匈奴不敢飲馬於河，置烽燧，然後敢牧馬。夫匈奴獨可以威服，不可以仁畜也。今以中國之盛，萬倍之資，遣百分之一以攻匈奴，譬猶以彊弩射且潰之癰也，必不留行矣。若是，則北發月氏可得而臣也。臣故曰擊之便。」安國曰：「不然。臣聞用兵者以飽待饑，正治以待其亂，定舍以待其勞，故接兵覆眾，伐國墮城，常坐而役敵國，此聖人之兵也。且臣聞之，衝風之衰，不能起毛羽；彊弩之末1>，力不能入魯縞2>。夫盛之有衰，猶朝3>之必莫4>也。今將卷甲輕舉，深入長敺，難以為功；從行則迫脅，衡行則中絕，疾則糧乏，徐則後利，不至千里，人馬乏食。兵法曰：『遺人獲也。』意者有它繆巧可以禽之，則臣不知也；不然，則未見深入之利也。臣故曰勿擊便。」\n〔注解〕\n\n彊弩之末：強弩射出的箭，到射程盡頭，已經沒有力道。比喻原本強大的力量已經衰竭，不能再發揮效用。見「強弩之末」。\n\n縞：音ㄍㄠˇ，白色的絲織品。\n\n朝：音ㄓㄠ，白天。\n\n莫：音ㄇㄨˋ，同「暮」，傍晚、太陽將落的時候。","story":"「長驅」是長距離地一路挺進，毫無阻礙。「直入」是毫無阻擋，直接進入的意思。典源《漢書．韓安國傳》之「深入長敺」，義與「長驅直入」相近。「敺」，音ㄑㄩ，同「驅」。韓安國是西漢時的著名政治家，七國之亂時，梁孝王拜韓安國為將，統帥梁國兵馬，平息了叛亂，此後韓安國威名傳播四方。後被景帝任為梁國內史，武帝時任北地都尉，後任御史大夫。當時匈奴派遣使者來和議，朝廷大臣分成主戰跟主和兩派。主戰者認為漢朝如今國勢強大，只需派遣少量兵馬，就可以輕易消滅匈奴，所以主張將匈奴趕盡殺絕。韓安國則極力反對，他認為︰疾風一旦衰弱了，連捲起羽毛那麼輕的東西都沒辦法；強弩射出的箭到了盡頭，連魯縞那樣薄的東西都射不穿。今日如果輕舉兵馬，迅速進入敵人的勢力範圍內，後援無以為繼，必然難以收到功效，反而沒有多久就會因為缺乏糧食，而被敵軍消滅。在韓安國的斡旋之下，漢朝決定與匈奴和親，讓北方邊疆維持了多年的和平。後來這句成語就從這裡演變而出，用來形容長距離一路挺進，毫無阻擋。也等於是軍強兵盛，戰事順利的意思。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1241&webMd=2&la=0","illustrationUrl":"","stage":"senior"},{"id":"moe-58","phrase":"入木三分","definition":"指墨跡深透木板三分，形容筆力遒勁。＃語出南朝宋．羊欣《筆陣圖》。後用「入木三分」比喻評論深刻中肯或描寫生動逼真。\n\n△「鞭辟入裡」","source":"＃南朝宋．羊欣《筆陣圖》（據唐．張懷瓘《書斷．卷二．王羲之》引）1>\n\n晉2>帝時，祭北郊，更3>祝版4>。工人削之，筆入木三分。三十三，書〈蘭亭序〉；三十七，書〈黃庭經〉。書訖，空中有語：「卿書感我，而況人乎！吾是天臺丈人。」自言真勝鍾繇，羲之書多不一體。\n〔注解〕\n\n典故或見於唐．李冗《獨異志》卷上。\n\n晉：朝代名，西元２６５∼４２０。司馬炎篡魏，吞併吳、蜀而有天下，國號晉，是為晉武帝。傳至愍帝，為前趙所滅，史稱西晉（西元２６５∼３１６）。後司馬睿即位於建康，是為晉元帝，史稱東晉（西元３１７∼４２０）。傳至恭帝，為劉裕所篡。此處所指應為東晉。\n\n更：改。\n\n祝版：古代祭祀所使用，寫有祭文的木版。\n\n〔參考資料〕\n唐．李冗《獨異志》卷上\n\n王獻之常為寫〈祭晉元帝廟祝文〉版，墨入木，深八分。","story":"王羲之，字逸少，東晉會稽人，曾經擔任右軍將軍，因此又稱為「王右軍」。他是古代著名的書法家，擅長行、草和楷書。一般而言，秀麗的字體會顯得柔弱無力，而蒼勁挺拔的字，又常會顯得厚重剛硬，然而王羲之所寫的字，卻是風格超凡，剛柔並濟，蒼勁豪邁中不失秀麗細緻。經過勤學苦練，筆力更是強健有力，無人能比。據說，有一次皇帝在北郊舉行祭祀的儀式，必須更換原本已寫有祝祭文的木版，工人們在削去王羲之寫過的木版時，發現他的筆跡竟然透入木版有三分之深！由此可見王羲之雄厚強勁的筆力。此事見於南朝宋．羊欣《筆陣圖》。王羲之在三十三歲時寫的〈蘭亭集序〉，以及三十七歲時寫的〈黃庭經〉，一向被譽為書法藝術中最好的小楷範本，後人尊稱他為「書聖」。而羊欣用來形容王羲之筆力的「入木三分」，後來演變為成語，用來比喻評論深刻中肯或描寫生動逼真。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=58&webMd=2&la=0","illustrationUrl":"","stage":"senior"},{"id":"moe-11556","phrase":"分秒必爭","definition":"一分一秒也要爭取。謂充分利用一切時間。如：「聯考在即，分秒必爭，片刻都不可放鬆。」","source":"","story":"","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=11556&webMd=2&la=0","illustrationUrl":"","stage":"senior"},{"id":"moe-1160","phrase":"爭先恐後","definition":"「爭先」，爭著在前。語出《左傳．襄公二十七年》。「恐後」，惟恐落於他人之後。語本《漢書．卷一四．諸侯王表》。「爭先恐後」指競相爭先，惟恐落後。","source":"「爭先」：《左傳．襄公二十七年》\n\n晉1>、楚2>爭先3>。晉人曰：「晉固為諸侯盟主，未有先晉者也。」楚人曰：「子言晉、楚匹也，若晉常先，是楚弱也。且晉、楚狎4>主諸侯之盟也久矣！豈專在晉？」叔向謂趙孟曰：「諸侯歸晉之德只，非歸其尸盟也。子務德，無爭先！且諸侯盟，小國固必有尸盟者，楚為晉細，不亦可乎？」乃先楚人。\n〔注解〕\n\n晉：周代諸侯國。春秋時據有今山西省大部分與河北省西南地區，地跨黃河兩岸。後為韓､趙､魏三家所分，遂亡。\n\n楚：國名。周成王封熊繹於楚，春秋時稱王，為戰國七雄之一。領有今湖南、湖北、安徽、浙江及河南南部，後為秦所滅。\n\n爭先：爭執於歃血盟誓的先後。\n\n狎：音ㄒㄧㄚˊ，更也，交換。\n\n「恐後」：《漢書．卷一四．諸侯王表》\n\n王莽知漢中外殫微，本末俱弱，亡所忌憚，生其姦心；因母后之權，假伊周之稱，顓作威福廟堂之上，不降階序而運天下。詐謀既成，遂據南面之尊，分遣五威之吏，馳傳天下，班行符命。漢諸侯王厥角稽首1>，奉上璽韍2>，惟恐在後，或乃稱美頌德，以求容媚，豈不哀哉！是以究其終始彊弱之變，明監戒焉。\n〔注解〕\n\n厥角稽首：叩頭時，以額頭觸地，即一種俯首至地的最敬禮。稽，音ㄑㄧˇ。\n\n璽韍：整組印璽。韍，音ㄈㄨˊ。","story":"「爭先恐後」係由「爭先」及「恐後」二語組合而成。\n\n「爭先」是出自《左傳．襄公二十七年》，提到晉國與楚國爭執於歃血盟誓的先後。晉國人認為：晉國一向是諸侯的盟主，從來沒有其他國家在晉國之前歃血的。楚國人認為：晉國和楚國的地位是對等的，如果讓晉國一直在先，這就是楚國比晉國弱小了。而且晉國、楚國交換著主持諸侯的結盟已有很長一段時間了，怎能說晉國一直是盟主呢？因雙方爭執不下，於是叔向對趙孟（二人均為晉國臣子）說：「諸侯是歸服於晉國的德行，不是歸服於晉國是否主持盟會。你致力於修明德行，不要去爭搶歃血的先後。諸侯結盟，小國本就應有一個出來負責結盟諸種事物的，此次就讓楚國做為晉國的小國，不也可以嗎？」因此就讓楚國先歃血。\n\n「恐後」是出自於《漢書．卷一四．諸侯王表》，內容是說王莽在西漢末年時，已察知漢朝即將走到盡頭，國力衰微，因而心生貪念，以外戚的權勢，作威作福，行使命令。其他的諸侯王看到這樣的局勢，都紛紛向王莽致上最敬禮，爭相奉上印璽，惟恐落於他人之後，有的則歌頌王莽的功德，極盡諂媚，真是令人感到悲哀！後來這兩個典源被合用成「爭先恐後」，指競相爭先，惟恐落後。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=1160&webMd=2&la=0","illustrationUrl":"","stage":"senior"},{"id":"moe-465","phrase":"後生可畏","definition":"比喻年輕人的成就超越先輩，令人敬畏。語出《論語．子罕》。","source":"《論語．子罕》\n\n子曰：「後生可畏，焉1>知來者之不如今也？四十、五十而無聞2>焉，斯亦不足畏也已。」\n〔注解〕\n\n焉：發問詞，怎麼。\n\n聞：名望、成就。","story":"孔子是春秋的賢人，於魯國從政時，魯國大治。後因政治理念與國君不合，周遊列國十三年，卻未受到其他國君的重用。晚年返回魯國，致力於古代典籍的整理。孔子秉持「有教無類」的精神，開平民教育的先河，門下有弟子三千人。孔門後學記錄孔子應答弟子、時人以及弟子間的問答之語，而成《論語》一書，其中可見孔子思想的脈絡，以及他的治學方式。由於孔子一生在政治上未能施展抱負，所以他對門下弟子的期許極大。在〈子罕〉篇中，孔子便說：「不可以小看年輕人啊！我們怎麼知道他們將來的成就，不會超過我們這一輩呢？如果一個人到了四、五十歲，還沒有任何可以稱道的成就，那他也不會有什麼了不起的作為。」一方面表現出孔子對年輕人的無窮期待，一方面也是警惕和勉勵年長者，如果只會倚老賣老而不肯努力，就會被後生晚輩趕上。後來「後生可畏」演變為成語，用來比喻年輕人的成就超越先輩，令人敬畏。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=465&webMd=2&la=0","illustrationUrl":"","stage":"senior"},{"id":"moe-186","phrase":"畏首畏尾","definition":"前也畏懼，後也畏懼。語出《左傳．文公十七年》。後用「畏首畏尾」形容疑慮顧忌，膽小怕事。\n\n△「左顧右盼」、「鹿死不擇音」、「鋌而走險」","source":"《左傳．文公十七年》\n\n晉侯不見鄭伯，以為貳於楚也。鄭子家使執訊而與之書，以告趙宣子，曰：「寡君即位三年，……十五年五月，陳侯自敝邑往朝于君。往年正月，燭之武往朝夷也。八月，寡君又往朝。以陳、蔡之密邇於楚而不敢貳焉，則敝邑之故也。雖敝邑之事君，何以不免？在位之中，一朝于襄，而再見于君。夷與孤之二三臣相及於絳，雖我小國，則蔑以過之矣。今大國曰：『爾未逞1>吾志。』敝邑有亡2>，無以加焉。古人有言曰：『畏首畏尾，身其餘幾？』又曰：『鹿死不擇音3>。』小國之事4>大國也，德，則5>其人也；不德，則其鹿也，鋌而走險6>，急何能擇？命之罔極，亦知亡矣……。」\n〔注解〕\n\n逞：滿足。\n\n亡：音ㄨㄤˊ，滅亡。\n\n鹿死不擇音：此句指鄭國如果再受晉國威逼，也許會投靠別國。就像被獵人追趕著的鹿一樣，為了活命，匆忙中就不選擇庇護之所。音，通「蔭」。\n\n事：侍奉。\n\n則：效法。\n\n鋌而走險：在窮途末路或受逼迫時採取冒險行動或不正當的行為。見「鋌而走險」。","story":"據《左傳．文公十七年》載，在春秋時代晉、楚兩國爭相當諸侯的盟主，有一次晉國大會諸侯，卻不見鄭國來參加，因此懷疑鄭國有二心。鄭國國君於是寫了一封信給晉國國君說：我國雖小，但三年來多次朝見晉君，盡了最大的誠意，但是你們還是懷疑我們的忠誠，那麼只有走上亡國的下場了。現在我國的處境是前頭也怕，後頭也怕。既害怕楚國來攻，又擔心晉國來犯，當我們被逼得走投無路時，就像被獵人追捕的鹿一樣，為了逃命，匆忙之間，無法審慎選擇庇護之所。如果晉國過分威逼，鄭國在窮途末路之餘，即使會走上滅亡的下場，也會用全副兵力抗晉，或倒向楚國。後來「畏首畏尾」演變為成語，用來形容疑慮顧忌，膽小怕事。","sourceUrl":"https://dict.idioms.moe.edu.tw/idiomView.jsp?ID=186&webMd=2&la=0","illustrationUrl":"","stage":"senior"}],"givenCellKeys":["0:0","3:1","4:3","6:4","7:6","9:7","10:9","12:10","13:12"]}'::jsonb, 'dict_idioms_2020_20260929', '', true, 'published')
on conflict (title, published_on) do update set
  difficulty = excluded.difficulty, puzzle_data = excluded.puzzle_data, source_version = excluded.source_version,
  is_daily_eligible = true, status = 'published', updated_at = now();

commit;
