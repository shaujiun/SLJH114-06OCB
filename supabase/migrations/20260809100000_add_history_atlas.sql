-- 歷史時光地圖：六冊可擴充架構、八年級章節、事件草稿、閱讀位置與圖片空間。

create or replace function public.can_manage_history_content()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.contact_book_is_admin() or exists (
    select 1
    from public.class_subjects class_subject
    join public.subjects subject on subject.id = class_subject.subject_id
    where class_subject.is_active
      and (lower(subject.code::text) = 'history' or subject.name = '歷史')
      and public.can_manage_subject(class_subject.id)
  );
$$;

revoke all on function public.can_manage_history_content() from public;
revoke all on function public.can_manage_history_content() from anon;
grant execute on function public.can_manage_history_content() to authenticated;

create table if not exists public.history_chapters (
  id uuid primary key default gen_random_uuid(),
  chapter_code citext not null unique,
  curriculum_edition text not null default '翰林',
  school_year_label text not null default '',
  grade_level smallint not null check (grade_level between 7 and 9),
  semester smallint not null check (semester in (1, 2)),
  volume_no smallint not null check (volume_no between 1 and 6),
  chapter_no smallint not null check (chapter_no between 1 and 20),
  title text not null,
  start_page integer check (start_page is null or start_page > 0),
  display_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint history_chapter_volume_number_unique unique (curriculum_edition, volume_no, chapter_no)
);

create table if not exists public.history_events (
  id uuid primary key default gen_random_uuid(),
  event_code citext not null unique,
  chapter_id uuid not null references public.history_chapters(id) on delete restrict,
  title text not null,
  start_year integer not null check (start_year between -5000 and 2200 and start_year <> 0),
  end_year integer check (end_year between -5000 and 2200 and end_year <> 0),
  display_date text not null default '',
  region text not null check (region in ('taiwan', 'china', 'japan', 'korea', 'world')),
  category text not null check (category in ('dynasty', 'politics', 'war', 'diplomacy', 'economy', 'society')),
  importance smallint not null default 2 check (importance between 1 and 3),
  summary text not null default '',
  cause_text text not null default '',
  process_text text not null default '',
  impact_text text not null default '',
  people text[] not null default '{}',
  keywords text[] not null default '{}',
  image_url text not null default '',
  image_source text not null default '',
  image_source_url text not null default '',
  resource_url text not null default '',
  source_note text not null default '',
  display_order integer not null default 0,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  published_at timestamptz,
  created_by uuid references public.contact_book_profiles(id) on delete set null,
  updated_by uuid references public.contact_book_profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint history_event_year_range_valid check (end_year is null or end_year >= start_year)
);

create table if not exists public.history_reader_positions (
  profile_id uuid primary key references public.contact_book_profiles(id) on delete cascade,
  chapter_id uuid references public.history_chapters(id) on delete set null,
  event_id uuid references public.history_events(id) on delete set null,
  volume_no smallint check (volume_no is null or volume_no between 1 and 6),
  focus_mode boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists history_chapters_scope_idx
  on public.history_chapters(grade_level, semester, volume_no, display_order);
create index if not exists history_events_chapter_year_idx
  on public.history_events(chapter_id, start_year, display_order);
create index if not exists history_events_status_year_idx
  on public.history_events(status, start_year, display_order);

alter table public.history_chapters enable row level security;
alter table public.history_events enable row level security;
alter table public.history_reader_positions enable row level security;

drop policy if exists history_chapters_authenticated_read on public.history_chapters;
create policy history_chapters_authenticated_read on public.history_chapters
for select to authenticated
using (is_active or public.can_manage_history_content());

drop policy if exists history_chapters_manager_write on public.history_chapters;
create policy history_chapters_manager_write on public.history_chapters
for all to authenticated
using (public.can_manage_history_content())
with check (public.can_manage_history_content());

drop policy if exists history_events_authenticated_read on public.history_events;
create policy history_events_authenticated_read on public.history_events
for select to authenticated
using (status = 'published' or public.can_manage_history_content());

drop policy if exists history_events_manager_write on public.history_events;
create policy history_events_manager_write on public.history_events
for all to authenticated
using (public.can_manage_history_content())
with check (public.can_manage_history_content());

drop policy if exists history_reader_positions_self on public.history_reader_positions;
create policy history_reader_positions_self on public.history_reader_positions
for all to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

grant select on public.history_chapters, public.history_events to authenticated;
grant insert, update, delete on public.history_chapters, public.history_events to authenticated;
grant select, insert, update, delete on public.history_reader_positions to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'history-media',
  'history-media',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists history_media_authenticated_read on storage.objects;
create policy history_media_authenticated_read on storage.objects
for select to authenticated
using (bucket_id = 'history-media');

drop policy if exists history_media_manager_insert on storage.objects;
create policy history_media_manager_insert on storage.objects
for insert to authenticated
with check (bucket_id = 'history-media' and public.can_manage_history_content());

drop policy if exists history_media_manager_update on storage.objects;
create policy history_media_manager_update on storage.objects
for update to authenticated
using (bucket_id = 'history-media' and public.can_manage_history_content())
with check (bucket_id = 'history-media' and public.can_manage_history_content());

drop policy if exists history_media_manager_delete on storage.objects;
create policy history_media_manager_delete on storage.objects
for delete to authenticated
using (bucket_id = 'history-media' and public.can_manage_history_content());

insert into public.history_chapters (
  chapter_code, curriculum_edition, school_year_label, grade_level, semester,
  volume_no, chapter_no, title, start_page, display_order, is_active
)
values
  ('hanlin-8-1-01', '翰林', '115', 8, 1, 3, 1, '商周至隋唐時期的國家與社會', 80, 3010, true),
  ('hanlin-8-1-02', '翰林', '115', 8, 1, 3, 2, '商周至隋唐時期的民族與文化', 90, 3020, true),
  ('hanlin-8-1-03', '翰林', '115', 8, 1, 3, 3, '宋元多民族並立的時期', 100, 3030, true),
  ('hanlin-8-1-04', '翰林', '115', 8, 1, 3, 4, '明清時期東亞世界的變動', 112, 3040, true),
  ('hanlin-8-1-05', '翰林', '115', 8, 1, 3, 5, '西力衝擊下的東亞世界', 124, 3050, true),
  ('hanlin-8-1-06', '翰林', '115', 8, 1, 3, 6, '清末變局與社會文化的變遷', 132, 3060, true),
  ('hanlin-8-2-01', '翰林', '114', 8, 2, 4, 1, '中華民國的建立', 90, 4010, true),
  ('hanlin-8-2-02', '翰林', '114', 8, 2, 4, 2, '舊傳統與新思潮', 100, 4020, true),
  ('hanlin-8-2-03', '翰林', '114', 8, 2, 4, 3, '現代國家的挑戰', 110, 4030, true),
  ('hanlin-8-2-04', '翰林', '114', 8, 2, 4, 4, '現代國家的變局', 118, 4040, true),
  ('hanlin-8-2-05', '翰林', '114', 8, 2, 4, 5, '共黨政權在中國', 128, 4050, true),
  ('hanlin-8-2-06', '翰林', '114', 8, 2, 4, 6, '當代東亞的局勢', 136, 4060, true)
on conflict (chapter_code) do update set
  curriculum_edition = excluded.curriculum_edition,
  school_year_label = excluded.school_year_label,
  grade_level = excluded.grade_level,
  semester = excluded.semester,
  volume_no = excluded.volume_no,
  chapter_no = excluded.chapter_no,
  title = excluded.title,
  start_page = excluded.start_page,
  display_order = excluded.display_order,
  is_active = excluded.is_active,
  updated_at = now();
-- 第一批 96 筆事件只建立可審核的時間軸草稿。摘要是自編索引句，教師可在發布前補寫原因、經過與影響。
with seed as (
  select * from jsonb_to_recordset($history_seed$
  [
    {"code":"h3c1-01","chapter":"hanlin-8-1-01","title":"商代國家形成","start":-1600,"end":-1046,"region":"china","category":"dynasty","summary":"商代以王權、宗族與祭祀建立早期國家體制。"},
    {"code":"h3c1-02","chapter":"hanlin-8-1-01","title":"西周封建制度","start":-1046,"region":"china","category":"politics","summary":"周王分封宗室與功臣，以宗法和禮樂維繫政治秩序。"},
    {"code":"h3c1-03","chapter":"hanlin-8-1-01","title":"春秋戰國的變局","start":-770,"end":-221,"region":"china","category":"war","summary":"諸侯競爭推動軍事、政治與社會制度的重大改變。"},
    {"code":"h3c1-04","chapter":"hanlin-8-1-01","title":"商鞅變法","start":-356,"region":"china","category":"politics","summary":"秦國透過變法強化中央權力、戶籍、軍功與農業。"},
    {"code":"h3c1-05","chapter":"hanlin-8-1-01","title":"秦統一中國","start":-221,"end":-206,"region":"china","category":"dynasty","summary":"秦建立皇帝制度與中央集權，並推行制度標準化。"},
    {"code":"h3c1-06","chapter":"hanlin-8-1-01","title":"漢朝建立與郡國並行","start":-202,"region":"china","category":"politics","summary":"西漢初期同時採用郡縣與封國，逐步鞏固中央統治。"},
    {"code":"h3c1-07","chapter":"hanlin-8-1-01","title":"魏晉南北朝的分裂局面","start":220,"end":589,"region":"china","category":"dynasty","summary":"政權更迭與南北分立改變政治、人口及族群關係。"},
    {"code":"h3c1-08","chapter":"hanlin-8-1-01","title":"隋唐帝國與制度發展","start":589,"end":907,"region":"china","category":"dynasty","summary":"隋唐重新統一，三省六部與科舉制度逐漸成熟。"},

    {"code":"h3c2-01","chapter":"hanlin-8-1-02","title":"匈奴與漢朝的互動","start":-200,"end":100,"region":"china","category":"diplomacy","summary":"戰爭、和親與邊疆經營共同塑造漢朝北方關係。"},
    {"code":"h3c2-02","chapter":"hanlin-8-1-02","title":"張騫通西域","start":-139,"region":"china","category":"diplomacy","summary":"漢朝使者前往西域，擴大中國與中亞的交通聯繫。"},
    {"code":"h3c2-03","chapter":"hanlin-8-1-02","title":"絲路交流發展","start":-130,"end":700,"region":"world","category":"economy","summary":"陸上交通促進商品、宗教、技術與文化跨區交流。"},
    {"code":"h3c2-04","chapter":"hanlin-8-1-02","title":"佛教傳入與發展","start":67,"end":600,"region":"china","category":"society","summary":"佛教經由交通路線傳入中國並逐步本土化。"},
    {"code":"h3c2-05","chapter":"hanlin-8-1-02","title":"人口南移與江南開發","start":311,"end":589,"region":"china","category":"economy","summary":"北方人口南遷帶動江南農業、手工業與城市發展。"},
    {"code":"h3c2-06","chapter":"hanlin-8-1-02","title":"北魏孝文帝改革","start":494,"region":"china","category":"politics","summary":"北魏推動制度與文化改革，加深北方族群交流。"},
    {"code":"h3c2-07","chapter":"hanlin-8-1-02","title":"唐代多元文化交流","start":618,"end":907,"region":"china","category":"society","summary":"唐代首都與交通網絡匯聚不同族群、宗教與文化。"},
    {"code":"h3c2-08","chapter":"hanlin-8-1-02","title":"日本遣唐使來華","start":630,"end":894,"region":"japan","category":"diplomacy","summary":"日本派遣使節學習唐代制度、文字、宗教與文化。"},

    {"code":"h3c3-01","chapter":"hanlin-8-1-03","title":"北宋建立","start":960,"end":1127,"region":"china","category":"dynasty","summary":"北宋結束五代十國局面並加強文官政治。"},
    {"code":"h3c3-02","chapter":"hanlin-8-1-03","title":"宋遼澶淵之盟","start":1005,"region":"china","category":"diplomacy","summary":"宋遼以和約維持長期邊境和平與經濟交流。"},
    {"code":"h3c3-03","chapter":"hanlin-8-1-03","title":"西夏建立","start":1038,"end":1227,"region":"china","category":"dynasty","summary":"党項人在西北建立西夏，形成多政權並立局勢。"},
    {"code":"h3c3-04","chapter":"hanlin-8-1-03","title":"金國建立","start":1115,"end":1234,"region":"china","category":"dynasty","summary":"女真人建立金國，改變宋遼之間的政治平衡。"},
    {"code":"h3c3-05","chapter":"hanlin-8-1-03","title":"靖康之變與南宋建立","start":1127,"region":"china","category":"war","summary":"金軍攻破北宋首都，宋室南遷後建立南宋。"},
    {"code":"h3c3-06","chapter":"hanlin-8-1-03","title":"蒙古帝國興起","start":1206,"region":"world","category":"dynasty","summary":"成吉思汗統一蒙古各部，開啟大規模對外擴張。"},
    {"code":"h3c3-07","chapter":"hanlin-8-1-03","title":"元朝建立與統一","start":1271,"end":1279,"region":"china","category":"dynasty","summary":"元朝建立後消滅南宋，再度統一中國。"},
    {"code":"h3c3-08","chapter":"hanlin-8-1-03","title":"宋元商業與科技發展","start":960,"end":1368,"region":"china","category":"economy","summary":"城市、海外貿易、紙幣、印刷與航海技術蓬勃發展。"},

    {"code":"h3c4-01","chapter":"hanlin-8-1-04","title":"明朝建立","start":1368,"end":1644,"region":"china","category":"dynasty","summary":"朱元璋建立明朝，重建中央集權政治。"},
    {"code":"h3c4-02","chapter":"hanlin-8-1-04","title":"明太祖廢除宰相","start":1380,"region":"china","category":"politics","summary":"皇帝直接統領中央行政部門，君主權力更加集中。"},
    {"code":"h3c4-03","chapter":"hanlin-8-1-04","title":"鄭和下西洋","start":1405,"end":1433,"region":"world","category":"diplomacy","summary":"明朝船隊多次航行印度洋，拓展外交與貿易往來。"},
    {"code":"h3c4-04","chapter":"hanlin-8-1-04","title":"明代海禁與倭寇問題","start":1371,"end":1567,"region":"china","category":"war","summary":"海禁、走私與沿海衝突交互影響東亞海域秩序。"},
    {"code":"h3c4-05","chapter":"hanlin-8-1-04","title":"日本戰國與幕府重建","start":1467,"end":1603,"region":"japan","category":"dynasty","summary":"日本歷經戰國統一，德川家康建立江戶幕府。"},
    {"code":"h3c4-06","chapter":"hanlin-8-1-04","title":"清軍入關","start":1644,"region":"china","category":"war","summary":"清軍進入山海關並逐步取代明朝統治中國。"},
    {"code":"h3c4-07","chapter":"hanlin-8-1-04","title":"康雍乾時期的統治","start":1661,"end":1795,"region":"china","category":"politics","summary":"清朝整合疆域、強化中央制度並發展多民族治理。"},
    {"code":"h3c4-08","chapter":"hanlin-8-1-04","title":"朝鮮王朝與清朝關係","start":1637,"end":1800,"region":"korea","category":"diplomacy","summary":"朝鮮在東亞政治變動中調整與明清兩朝的關係。"},

    {"code":"h3c5-01","chapter":"hanlin-8-1-05","title":"歐洲大航海時代","start":1492,"end":1700,"region":"world","category":"economy","summary":"遠洋航行連結各洲，也帶來殖民、貿易與文化衝擊。"},
    {"code":"h3c5-02","chapter":"hanlin-8-1-05","title":"葡萄牙取得澳門居留","start":1557,"region":"china","category":"diplomacy","summary":"葡萄牙人在澳門發展貿易，成為中西交流據點。"},
    {"code":"h3c5-03","chapter":"hanlin-8-1-05","title":"傳教士來華與西學交流","start":1583,"end":1800,"region":"china","category":"society","summary":"傳教士帶來科技知識，也將中國文化介紹到歐洲。"},
    {"code":"h3c5-04","chapter":"hanlin-8-1-05","title":"英國使節訪華與通商衝突","start":1793,"region":"china","category":"diplomacy","summary":"中英對外交禮制與貿易制度的認知差異逐漸擴大。"},
    {"code":"h3c5-05","chapter":"hanlin-8-1-05","title":"鴉片戰爭","start":1840,"end":1842,"region":"china","category":"war","summary":"清朝戰敗後簽訂條約，傳統對外關係受到重大衝擊。"},
    {"code":"h3c5-06","chapter":"hanlin-8-1-05","title":"自強運動","start":1861,"end":1895,"region":"china","category":"politics","summary":"清朝官員引進西方軍事與工業技術以求富國強兵。"},
    {"code":"h3c5-07","chapter":"hanlin-8-1-05","title":"日本明治維新","start":1868,"region":"japan","category":"politics","summary":"日本推動中央集權、工業化與制度改革。"},
    {"code":"h3c5-08","chapter":"hanlin-8-1-05","title":"甲午戰爭與馬關條約","start":1894,"end":1895,"region":"china","category":"war","summary":"清朝戰敗改變東亞權力平衡，也加深改革危機。"},

    {"code":"h3c6-01","chapter":"hanlin-8-1-06","title":"戊戌變法","start":1898,"region":"china","category":"politics","summary":"改革人士嘗試從制度、教育與經濟推動國家變革。"},
    {"code":"h3c6-02","chapter":"hanlin-8-1-06","title":"義和團與八國聯軍","start":1900,"end":1901,"region":"china","category":"war","summary":"排外衝突與列強出兵使清朝面臨更深政治危機。"},
    {"code":"h3c6-03","chapter":"hanlin-8-1-06","title":"清末新政","start":1901,"end":1911,"region":"china","category":"politics","summary":"清廷推動軍事、教育、行政與法制改革。"},
    {"code":"h3c6-04","chapter":"hanlin-8-1-06","title":"廢除科舉制度","start":1905,"region":"china","category":"society","summary":"傳統選官考試結束，新式教育與人才培養逐步發展。"},
    {"code":"h3c6-05","chapter":"hanlin-8-1-06","title":"中國同盟會成立","start":1905,"region":"china","category":"politics","summary":"革命團體整合力量，提出推翻清朝的政治目標。"},
    {"code":"h3c6-06","chapter":"hanlin-8-1-06","title":"立憲運動與地方參政","start":1906,"end":1911,"region":"china","category":"politics","summary":"清末立憲改革帶動地方士紳與新式政治參與。"},
    {"code":"h3c6-07","chapter":"hanlin-8-1-06","title":"新式教育與報刊發展","start":1895,"end":1911,"region":"china","category":"society","summary":"學堂、留學與報刊傳播促成新知識和公共討論。"},
    {"code":"h3c6-08","chapter":"hanlin-8-1-06","title":"辛亥革命","start":1911,"region":"china","category":"war","summary":"各地革命與政治協商終結清朝統治。"},

    {"code":"h4c1-01","chapter":"hanlin-8-2-01","title":"武昌起義","start":1911,"region":"china","category":"war","summary":"革命軍起事帶動各省響應，清朝統治迅速瓦解。"},
    {"code":"h4c1-02","chapter":"hanlin-8-2-01","title":"中華民國成立","start":1912,"region":"china","category":"dynasty","summary":"亞洲第一個共和國成立，政治制度進入新階段。"},
    {"code":"h4c1-03","chapter":"hanlin-8-2-01","title":"《臨時約法》公布","start":1912,"region":"china","category":"politics","summary":"以法律規範共和政體與政府權力的基本架構。"},
    {"code":"h4c1-04","chapter":"hanlin-8-2-01","title":"宋教仁案與二次革命","start":1913,"region":"china","category":"politics","summary":"政黨政治受挫，中央與革命勢力再度爆發衝突。"},
    {"code":"h4c1-05","chapter":"hanlin-8-2-01","title":"袁世凱稱帝","start":1915,"end":1916,"region":"china","category":"politics","summary":"恢復帝制的企圖引發各地反對與護國戰爭。"},
    {"code":"h4c1-06","chapter":"hanlin-8-2-01","title":"軍閥割據","start":1916,"end":1928,"region":"china","category":"war","summary":"中央權力衰弱，各地軍事勢力競逐政治控制。"},
    {"code":"h4c1-07","chapter":"hanlin-8-2-01","title":"中國參與第一次世界大戰","start":1917,"end":1918,"region":"world","category":"diplomacy","summary":"中國希望藉參戰改善國際地位並收回列強權益。"},
    {"code":"h4c1-08","chapter":"hanlin-8-2-01","title":"護法運動","start":1917,"end":1922,"region":"china","category":"politics","summary":"南方政治勢力以維護共和法統為號召進行抗爭。"},

    {"code":"h4c2-01","chapter":"hanlin-8-2-02","title":"新文化運動","start":1915,"end":1923,"region":"china","category":"society","summary":"知識分子倡導民主、科學與文化革新。"},
    {"code":"h4c2-02","chapter":"hanlin-8-2-02","title":"白話文運動","start":1917,"region":"china","category":"society","summary":"白話文逐漸取代文言文，擴大知識與文學傳播。"},
    {"code":"h4c2-03","chapter":"hanlin-8-2-02","title":"五四運動","start":1919,"region":"china","category":"society","summary":"學生抗議外交決定，進一步帶動民族與社會運動。"},
    {"code":"h4c2-04","chapter":"hanlin-8-2-02","title":"馬克思主義傳播","start":1919,"end":1921,"region":"china","category":"society","summary":"新思潮在知識界與青年群體中快速傳播。"},
    {"code":"h4c2-05","chapter":"hanlin-8-2-02","title":"中國共產黨成立","start":1921,"region":"china","category":"politics","summary":"共產黨組織建立，成為往後中國政治的重要力量。"},
    {"code":"h4c2-06","chapter":"hanlin-8-2-02","title":"第一次國共合作","start":1924,"end":1927,"region":"china","category":"politics","summary":"國民黨與共產黨合作推動反軍閥與國家統一。"},
    {"code":"h4c2-07","chapter":"hanlin-8-2-02","title":"黃埔軍校成立","start":1924,"region":"china","category":"politics","summary":"軍校培養革命軍事人才，支援國民革命。"},
    {"code":"h4c2-08","chapter":"hanlin-8-2-02","title":"北伐","start":1926,"end":1928,"region":"china","category":"war","summary":"國民革命軍北上擊敗主要軍閥，完成形式上的統一。"},

    {"code":"h4c3-01","chapter":"hanlin-8-2-03","title":"南京國民政府成立","start":1927,"region":"china","category":"politics","summary":"國民政府以南京為中心建立新的中央統治。"},
    {"code":"h4c3-02","chapter":"hanlin-8-2-03","title":"十年建設","start":1928,"end":1937,"region":"china","category":"economy","summary":"政府推動交通、金融、工業與制度建設。"},
    {"code":"h4c3-03","chapter":"hanlin-8-2-03","title":"國共分裂與武裝衝突","start":1927,"end":1937,"region":"china","category":"war","summary":"國民黨與共產黨由合作轉為長期對抗。"},
    {"code":"h4c3-04","chapter":"hanlin-8-2-03","title":"九一八事變","start":1931,"region":"china","category":"war","summary":"日本占領中國東北，東亞侵略局勢升高。"},
    {"code":"h4c3-05","chapter":"hanlin-8-2-03","title":"滿洲國成立","start":1932,"region":"china","category":"politics","summary":"日本扶植政權控制中國東北地區。"},
    {"code":"h4c3-06","chapter":"hanlin-8-2-03","title":"紅軍長征","start":1934,"end":1936,"region":"china","category":"war","summary":"共產黨軍隊轉移至西北並重組領導核心。"},
    {"code":"h4c3-07","chapter":"hanlin-8-2-03","title":"西安事變","start":1936,"region":"china","category":"politics","summary":"事件促成停止內戰、共同抗日的政治轉折。"},
    {"code":"h4c3-08","chapter":"hanlin-8-2-03","title":"中日戰爭全面爆發","start":1937,"end":1945,"region":"china","category":"war","summary":"中國進入長期全面抗戰，社會與國家承受巨大損失。"},

    {"code":"h4c4-01","chapter":"hanlin-8-2-04","title":"第二次國共合作","start":1937,"end":1945,"region":"china","category":"politics","summary":"國共兩黨在抗日背景下再次合作。"},
    {"code":"h4c4-02","chapter":"hanlin-8-2-04","title":"南京大屠殺","start":1937,"region":"china","category":"war","summary":"日軍占領南京後造成大量平民與戰俘傷亡。"},
    {"code":"h4c4-03","chapter":"hanlin-8-2-04","title":"戰時首都遷往重慶","start":1937,"end":1945,"region":"china","category":"politics","summary":"國民政府向西南遷移並維持長期抗戰。"},
    {"code":"h4c4-04","chapter":"hanlin-8-2-04","title":"太平洋戰爭爆發","start":1941,"end":1945,"region":"world","category":"war","summary":"東亞戰爭與第二次世界大戰進一步連結。"},
    {"code":"h4c4-05","chapter":"hanlin-8-2-04","title":"日本投降與戰爭結束","start":1945,"region":"world","category":"war","summary":"第二次世界大戰結束，東亞政治秩序重新調整。"},
    {"code":"h4c4-06","chapter":"hanlin-8-2-04","title":"重慶談判","start":1945,"region":"china","category":"politics","summary":"國共雙方嘗試協商戰後政治安排。"},
    {"code":"h4c4-07","chapter":"hanlin-8-2-04","title":"國共內戰全面爆發","start":1946,"end":1949,"region":"china","category":"war","summary":"政治談判破裂後，雙方展開大規模軍事衝突。"},
    {"code":"h4c4-08","chapter":"hanlin-8-2-04","title":"兩岸分治局面形成","start":1949,"region":"china","category":"politics","summary":"中華人民共和國成立，中華民國政府遷臺。"},

    {"code":"h4c5-01","chapter":"hanlin-8-2-05","title":"中華人民共和國成立","start":1949,"region":"china","category":"dynasty","summary":"中國共產黨建立新的國家政權與政治體制。"},
    {"code":"h4c5-02","chapter":"hanlin-8-2-05","title":"土地改革","start":1950,"end":1953,"region":"china","category":"politics","summary":"政權重新分配農村土地並改變傳統社會結構。"},
    {"code":"h4c5-03","chapter":"hanlin-8-2-05","title":"第一個五年計畫","start":1953,"end":1957,"region":"china","category":"economy","summary":"中國仿效蘇聯模式，優先推動重工業與計畫經濟。"},
    {"code":"h4c5-04","chapter":"hanlin-8-2-05","title":"大躍進與人民公社","start":1958,"end":1961,"region":"china","category":"economy","summary":"激進政策造成生產混亂與嚴重社會代價。"},
    {"code":"h4c5-05","chapter":"hanlin-8-2-05","title":"文化大革命","start":1966,"end":1976,"region":"china","category":"society","summary":"政治運動衝擊教育、文化、經濟與社會秩序。"},
    {"code":"h4c5-06","chapter":"hanlin-8-2-05","title":"中國取得聯合國席位","start":1971,"region":"world","category":"diplomacy","summary":"中華人民共和國取得中國在聯合國的代表權。"},
    {"code":"h4c5-07","chapter":"hanlin-8-2-05","title":"改革開放","start":1978,"region":"china","category":"economy","summary":"中國調整經濟政策，逐步擴大市場機制與對外交流。"},
    {"code":"h4c5-08","chapter":"hanlin-8-2-05","title":"中國加入世界貿易組織","start":2001,"region":"world","category":"economy","summary":"中國更深度參與全球貿易與生產網絡。"},

    {"code":"h4c6-01","chapter":"hanlin-8-2-06","title":"朝鮮半島分裂","start":1948,"region":"korea","category":"politics","summary":"冷戰對立促成南北韓分別建立政府。"},
    {"code":"h4c6-02","chapter":"hanlin-8-2-06","title":"韓戰","start":1950,"end":1953,"region":"korea","category":"war","summary":"南北韓衝突擴大為國際戰爭，分裂局面延續。"},
    {"code":"h4c6-03","chapter":"hanlin-8-2-06","title":"日本戰後民主化改革","start":1945,"end":1952,"region":"japan","category":"politics","summary":"盟軍占領下的改革重整日本政治與社會制度。"},
    {"code":"h4c6-04","chapter":"hanlin-8-2-06","title":"日本經濟高度成長","start":1955,"end":1973,"region":"japan","category":"economy","summary":"出口、工業與技術發展使日本成為經濟強國。"},
    {"code":"h4c6-05","chapter":"hanlin-8-2-06","title":"冷戰下的東亞聯盟體系","start":1950,"end":1991,"region":"world","category":"diplomacy","summary":"美蘇競爭影響東亞各國安全、外交與發展路線。"},
    {"code":"h4c6-06","chapter":"hanlin-8-2-06","title":"亞洲四小龍經濟起飛","start":1960,"end":1990,"region":"world","category":"economy","summary":"臺灣、南韓、香港與新加坡發展出口導向經濟。"},
    {"code":"h4c6-07","chapter":"hanlin-8-2-06","title":"美中關係正常化","start":1972,"end":1979,"region":"world","category":"diplomacy","summary":"美國與中國逐步改善關係並正式建立外交關係。"},
    {"code":"h4c6-08","chapter":"hanlin-8-2-06","title":"東亞區域交流深化","start":1990,"end":2020,"region":"world","category":"economy","summary":"貿易、投資、文化與人口流動使東亞連結更加密切。"}
  ]
  $history_seed$::jsonb) as item(
    code text,
    chapter text,
    title text,
    start integer,
    "end" integer,
    region text,
    category text,
    summary text
  )
)
insert into public.history_events (
  event_code, chapter_id, title, start_year, end_year, region, category,
  importance, summary, source_note, display_order, status
)
select
  seed.code,
  chapter.id,
  seed.title,
  seed.start,
  seed."end",
  seed.region,
  seed.category,
  2,
  seed.summary,
  '依翰林國中社會八年級歷史目次編排之自編事件索引；發布前須由管理者或歷史老師審核。',
  (row_number() over (partition by seed.chapter order by seed.start, seed.code) * 10)::integer,
  'draft'
from seed
join public.history_chapters chapter on chapter.chapter_code = seed.chapter
on conflict (event_code) do update set
  chapter_id = excluded.chapter_id,
  title = excluded.title,
  start_year = excluded.start_year,
  end_year = excluded.end_year,
  region = excluded.region,
  category = excluded.category,
  summary = excluded.summary,
  source_note = excluded.source_note,
  display_order = excluded.display_order,
  updated_at = now();

insert into public.learning_systems (
  subject_code, subject_name, description, launch_url, display_order,
  weekly_minimum, weekly_maximum, audience_scope, is_active
)
values (
  'history',
  '歷史科',
  '用時間軸串起八年級中國與東亞的重要人物、制度與事件。',
  'https://shaujiun.github.io/SLJH-learning-hub/?subject=history',
  30,
  1,
  1,
  'common',
  true
)
on conflict (subject_code) do update set
  subject_name = excluded.subject_name,
  description = excluded.description,
  launch_url = excluded.launch_url,
  audience_scope = excluded.audience_scope,
  is_active = excluded.is_active,
  updated_at = now();
