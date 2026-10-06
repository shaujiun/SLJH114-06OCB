begin;

create table if not exists public.admission_competition_catalog (
  id uuid primary key default gen_random_uuid(),
  rule_version text not null default 'yunlin-113-05-16',
  code text not null unique check (code ~ '^(international|national|county)-[0-9]{2}$'),
  tier text not null check (tier in ('international', 'national', 'county')),
  name text not null check (length(trim(name)) between 2 and 200),
  comparison_event text not null default '',
  detail_note text not null default '',
  sort_order integer not null check (sort_order > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists admission_competition_catalog_tier_sort_idx
  on public.admission_competition_catalog(tier, sort_order)
  where is_active;

create table if not exists public.admission_self_checks (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null unique references public.students(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  rule_version text not null default 'yunlin-113-05-16',
  preference_order smallint check (preference_order between 1 and 50),
  economic_weakness boolean,
  nearby_enrollment boolean,
  no_truancy_semesters smallint not null default 0 check (no_truancy_semesters between 0 and 5),
  discipline_status text check (discipline_status in ('none', 'warnings_up_to_2', 'minor_demerit_or_more')),
  balanced_domains jsonb not null default '[]'::jsonb check (jsonb_typeof(balanced_domains) = 'array'),
  remote_school_band text check (remote_school_band in ('seven_or_less', 'eight_to_twelve', 'other')),
  major_merits smallint not null default 0 check (major_merits between 0 and 99),
  minor_merits smallint not null default 0 check (minor_merits between 0 and 99),
  commendations smallint not null default 0 check (commendations between 0 and 99),
  fitness_qualified_items smallint not null default 0 check (fitness_qualified_items between 0 and 4),
  review_status text not null default 'self_reported'
    check (review_status in ('self_reported', 'reviewed', 'needs_info')),
  admin_note text not null default '' check (length(admin_note) <= 1000),
  reviewed_by uuid references public.contact_book_profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists admission_self_checks_class_updated_idx
  on public.admission_self_checks(class_id, updated_at desc);

create table if not exists public.admission_competition_entries (
  id uuid primary key default gen_random_uuid(),
  self_check_id uuid not null references public.admission_self_checks(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  catalog_id uuid references public.admission_competition_catalog(id) on delete restrict,
  catalog_code text,
  competition_name text not null check (length(trim(competition_name)) between 2 and 200),
  competition_detail text not null default '' check (length(competition_detail) <= 300),
  school_year smallint not null check (school_year between 100 and 999),
  tier text not null check (tier in ('international', 'national', 'county')),
  award_level text not null check (award_level in ('first_to_fourth', 'first', 'second', 'third', 'fourth_or_selected', 'fourth_to_sixth')),
  team_scale text not null check (team_scale in ('individual', 'team_4_19', 'team_20_plus')),
  review_status text not null default 'listed'
    check (review_status in ('listed', 'pending', 'approved', 'rejected')),
  admin_note text not null default '' check (length(admin_note) <= 1000),
  reviewed_by uuid references public.contact_book_profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint admission_competition_catalog_snapshot_check check (
    (catalog_id is not null and catalog_code is not null)
    or (catalog_id is null and catalog_code is null)
  )
);

create index if not exists admission_competition_entries_student_year_idx
  on public.admission_competition_entries(student_id, school_year, created_at);
create index if not exists admission_competition_entries_class_review_idx
  on public.admission_competition_entries(class_id, review_status, updated_at desc);

drop trigger if exists admission_competition_catalog_set_updated_at on public.admission_competition_catalog;
create trigger admission_competition_catalog_set_updated_at
before update on public.admission_competition_catalog
for each row execute function public.contact_book_set_updated_at();

drop trigger if exists admission_self_checks_set_updated_at on public.admission_self_checks;
create trigger admission_self_checks_set_updated_at
before update on public.admission_self_checks
for each row execute function public.contact_book_set_updated_at();

drop trigger if exists admission_competition_entries_set_updated_at on public.admission_competition_entries;
create trigger admission_competition_entries_set_updated_at
before update on public.admission_competition_entries
for each row execute function public.contact_book_set_updated_at();

alter table public.admission_competition_catalog enable row level security;
alter table public.admission_self_checks enable row level security;
alter table public.admission_competition_entries enable row level security;

drop policy if exists admission_competition_catalog_read_approved on public.admission_competition_catalog;
create policy admission_competition_catalog_read_approved
on public.admission_competition_catalog
for select to authenticated
using (is_active and public.is_approved_user());

drop policy if exists admission_competition_catalog_admin_manage on public.admission_competition_catalog;
create policy admission_competition_catalog_admin_manage
on public.admission_competition_catalog
for all to authenticated
using (public.contact_book_is_admin())
with check (public.contact_book_is_admin());

drop policy if exists admission_self_checks_read_allowed on public.admission_self_checks;
create policy admission_self_checks_read_allowed
on public.admission_self_checks
for select to authenticated
using (public.is_student_self(student_id) or public.can_manage_class(class_id));

drop policy if exists admission_competition_entries_read_allowed on public.admission_competition_entries;
create policy admission_competition_entries_read_allowed
on public.admission_competition_entries
for select to authenticated
using (public.is_student_self(student_id) or public.can_manage_class(class_id));

revoke all on public.admission_competition_catalog from public, anon, authenticated;
revoke all on public.admission_self_checks from public, anon, authenticated;
revoke all on public.admission_competition_entries from public, anon, authenticated;
grant select on public.admission_competition_catalog to authenticated;
grant select on public.admission_self_checks to authenticated;
grant select on public.admission_competition_entries to authenticated;

insert into public.admission_competition_catalog
  (code, tier, name, comparison_event, detail_note, sort_order)
values
  ('international-01','international','美國國際科技展覽會','','',1),
  ('international-02','international','加拿大科學展覽會','','',2),
  ('international-03','international','香港聯校科學展覽會','','',3),
  ('international-04','international','新加坡科技展覽會','','',4),
  ('international-05','international','國際（亞洲）科學博覽會','','',5),
  ('international-06','international','美國國際永續發展科技展覽會','','',6),
  ('international-07','international','荷蘭國際環境及永續發展展覽會','','',7),
  ('international-08','international','歐盟青年科學家競賽','','',8),
  ('international-09','international','倫敦國際青年科學論壇','','',9),
  ('international-10','international','比利時科學博覽會','','',10),
  ('international-11','international','義大利科學博覽會','','',11),
  ('international-12','international','土耳其音樂科學工程博覽會','','',12),
  ('international-13','international','突尼西亞科學博覽會','','',13),
  ('international-14','international','巴西科學博覽會','','',14),
  ('international-15','international','俄羅斯科學博覽會','','',15),
  ('international-16','international','韓國科學博覽會','','',16),
  ('international-17','international','國際瑞士人才論壇','','',17),
  ('international-18','international','青年奧林匹克運動會','','',18),
  ('international-19','international','亞洲青年運動會','','',19),
  ('international-20','international','奧林匹克運動會','','',20),
  ('international-21','international','亞洲運動會','','',21),
  ('international-22','international','亞洲沙灘運動會','','',22),
  ('international-23','international','亞洲室內及武藝運動會','','',23),
  ('international-24','international','東亞青年運動會','','',24),
  ('international-25','international','世界中學生運動會','','',25),
  ('international-26','international','亞洲帕拉運動會','','',26),
  ('international-27','international','帕拉林匹克運動會','','',27),
  ('international-28','international','聽障達福林匹克運動會','','',28),
  ('international-29','international','亞太聽障運動會','','',29),
  ('international-30','international','世界運動會','','',30),
  ('international-31','international','世界聽障青年運動會','','',31),
  ('international-32','international','亞洲帕拉青年運動會','','',32),
  ('national-01','national','中華民國中小學科學展覽會','','',1),
  ('national-02','national','臺灣國際科學展覽會','','',2),
  ('national-03','national','全國學生創意戲劇比賽','','',3),
  ('national-04','national','教育部文藝創作獎','','',4),
  ('national-05','national','全國學生音樂比賽','','',5),
  ('national-06','national','全國學生美術比賽','','',6),
  ('national-07','national','全國師生鄉土歌謠比賽','','',7),
  ('national-08','national','全國學生圖畫書創作獎','','',8),
  ('national-09','national','臺灣「能」－永續能源創意實作競賽','','',9),
  ('national-10','national','全國手擲機飛行競賽','','',10),
  ('national-11','national','全國中小學客家藝文競賽','','',11),
  ('national-12','national','全國原住民兒童繪畫創作比賽','','',12),
  ('national-13','national','原住民族語戲劇競賽','','',13),
  ('national-14','national','原住民族語單詞競賽','','',14),
  ('national-15','national','全國綠建築繪畫徵圖比賽','','',15),
  ('national-16','national','全國技能競賽暨亞洲技能競賽及國際技能競賽國手選拔賽','','',16),
  ('national-17','national','環境知識競賽','','',17),
  ('national-18','national','全國語文競賽','','',18),
  ('national-19','national','全國學生舞蹈比賽','','',19),
  ('national-20','national','學校環境教育實作競賽','','',20),
  ('national-21','national','海洋科普繪本創作徵選','','',21),
  ('national-22','national','海洋詩創作徵選','','',22),
  ('national-23','national','全國運動會','','',23),
  ('national-24','national','全民運動會','','',24),
  ('national-25','national','全國身心障礙國民運動會','','',25),
  ('national-26','national','全國原住民族運動會','','',26),
  ('national-27','national','全國中等學校運動會','','',27),
  ('national-28','national','國民中學籃球聯賽','','',28),
  ('national-29','national','國民中學排球聯賽','','',29),
  ('national-30','national','中等學校足球聯賽','','',30),
  ('national-31','national','中小學女子壘球聯賽','','',31),
  ('national-32','national','國中棒球硬式組聯賽','','',32),
  ('national-33','national','國中棒球軟式組聯賽','','',33),
  ('national-34','national','原住民雲端科展','','',34),
  ('national-35','national','全國聽覺障礙國民國語文競賽','','',35),
  ('county-01','county','雲林縣公私立國民中小學科學展覽會','中華民國中小學科學展覽會','物理、化學、生物、地球科學、數學、生活與應用科學',1),
  ('county-02','county','全縣國中技藝教育課程技藝競賽','','各職群競賽組別依當年度簡章',2),
  ('county-03','county','全縣語文競賽','全國語文競賽','依附表 3 與當年度公告採計項目',3),
  ('county-04','county','全縣學生美術比賽','全國學生美術比賽','依附表 4 與當年度公告採計項目',4),
  ('county-05','county','全縣學生舞蹈比賽','全國學生舞蹈比賽','依附表 5 與當年度公告採計項目',5),
  ('county-06','county','全縣學生音樂暨師生鄉土歌謠比賽','全國學生音樂比賽、全國師生鄉土歌謠比賽','依附表 6 與當年度公告採計項目',6),
  ('county-07','county','雲林縣學生創意戲劇比賽','全國學生創意戲劇比賽','依附表 7 與當年度公告採計項目',7),
  ('county-08','county','雲林縣中小學聯合運動會','全國運動會、全民運動會、全國中等學校運動會','依附表 8 與當年度公告採計項目',8),
  ('county-09','county','全縣運動會','全國運動會、全民運動會、全國中等學校運動會','依附表 9 與當年度公告採計項目',9),
  ('county-10','county','春、秋季縣長盃競賽','全國運動會、全民運動會、全國中等學校運動會、國中籃球聯賽、國中排球聯賽、國中足球聯賽','依附表 10 與當年度公告採計項目',10),
  ('county-11','county','雲林縣環保知識競賽','全國環保知識競賽','依附表 11 與當年度公告採計項目',11),
  ('county-12','county','雲林縣英語學藝競賽','','依附表 12 與當年度公告採計項目',12),
  ('county-13','county','雲林縣性別平等教育學生海報比賽','','依附表 13 與當年度公告採計項目',13),
  ('county-14','county','「雲林好品」思辯與實踐－奧瑞岡辯論比賽','','依附表 14 與當年度公告採計項目',14),
  ('county-15','county','雲林縣 SCRATCH 程式設計競賽','','依附表 15 與當年度公告採計項目',15),
  ('county-16','county','豐泰文教盃全國機器人年賽暨雲林縣國中機器人創作大賽','','依附表 16 與當年度公告採計項目',16),
  ('county-17','county','雲林縣縣長盃硬筆書法比賽','','自 110 學年度起辦理之競賽',17),
  ('county-18','county','雲林縣科技教育創意實作競賽','','生活科技、資訊科技；自 111 學年度起辦理之競賽',18),
  ('county-19','county','雲林縣健康樂活青年反毒飆舞尬舞暨大專、青少年組全國錦標賽','','自 112 學年度起辦理之競賽',19),
  ('county-20','county','雲林縣海洋科普繪本創作徵選','全國海洋科普繪本創作徵選','自 113 學年度起辦理之競賽',20),
  ('county-21','county','雲林縣海洋詩創作徵選','全國海洋詩創作徵選','自 113 學年度起辦理之競賽',21)
on conflict (code) do update
set tier = excluded.tier,
    name = excluded.name,
    comparison_event = excluded.comparison_event,
    detail_note = excluded.detail_note,
    sort_order = excluded.sort_order,
    is_active = true,
    updated_at = now();

create or replace function public.save_my_admission_self_check(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_student public.students%rowtype;
  target_id uuid;
  normalized_domains jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select student.* into target_student
  from public.students student
  join public.contact_book_profiles profile on profile.id = student.profile_id
  where student.profile_id = auth.uid()
    and student.is_active
    and profile.approval_status = 'approved'
    and profile.is_active;
  if not found then raise exception 'student_required' using errcode = '42501'; end if;
  if jsonb_typeof(coalesce(p_payload, 'null'::jsonb)) <> 'object' then
    raise exception 'invalid_admission_check';
  end if;
  if p_payload ? 'balancedDomains'
    and jsonb_typeof(p_payload->'balancedDomains') <> 'array' then
    raise exception 'invalid_admission_check';
  end if;

  select coalesce(jsonb_agg(domain order by domain), '[]'::jsonb)
  into normalized_domains
  from (
    select distinct value as domain
    from jsonb_array_elements_text(coalesce(p_payload->'balancedDomains', '[]'::jsonb))
    where value in ('health', 'arts', 'integrated', 'technology')
  ) allowed_domains;

  insert into public.admission_self_checks (
    student_id, class_id, rule_version, preference_order,
    economic_weakness, nearby_enrollment, no_truancy_semesters,
    discipline_status, balanced_domains, remote_school_band,
    major_merits, minor_merits, commendations, fitness_qualified_items,
    review_status, reviewed_by, reviewed_at
  ) values (
    target_student.id,
    target_student.class_id,
    'yunlin-113-05-16',
    nullif(p_payload->>'preferenceOrder', '')::smallint,
    nullif(p_payload->>'economicWeakness', '')::boolean,
    nullif(p_payload->>'nearbyEnrollment', '')::boolean,
    coalesce(nullif(p_payload->>'noTruancySemesters', '')::smallint, 0),
    nullif(p_payload->>'disciplineStatus', ''),
    normalized_domains,
    nullif(p_payload->>'remoteSchoolBand', ''),
    coalesce(nullif(p_payload->>'majorMerits', '')::smallint, 0),
    coalesce(nullif(p_payload->>'minorMerits', '')::smallint, 0),
    coalesce(nullif(p_payload->>'commendations', '')::smallint, 0),
    coalesce(nullif(p_payload->>'fitnessQualifiedItems', '')::smallint, 0),
    'self_reported', null, null
  )
  on conflict (student_id) do update
  set preference_order = excluded.preference_order,
      economic_weakness = excluded.economic_weakness,
      nearby_enrollment = excluded.nearby_enrollment,
      no_truancy_semesters = excluded.no_truancy_semesters,
      discipline_status = excluded.discipline_status,
      balanced_domains = excluded.balanced_domains,
      remote_school_band = excluded.remote_school_band,
      major_merits = excluded.major_merits,
      minor_merits = excluded.minor_merits,
      commendations = excluded.commendations,
      fitness_qualified_items = excluded.fitness_qualified_items,
      review_status = 'self_reported',
      reviewed_by = null,
      reviewed_at = null,
      updated_at = now()
  returning id into target_id;

  return target_id;
exception
  when check_violation or invalid_text_representation or numeric_value_out_of_range then
    raise exception 'invalid_admission_check';
end;
$$;

create or replace function public.save_my_admission_competition(
  p_entry_id uuid,
  p_catalog_code text,
  p_custom_name text,
  p_competition_detail text,
  p_school_year smallint,
  p_tier text,
  p_award_level text,
  p_team_scale text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_student public.students%rowtype;
  target_check_id uuid;
  target_catalog public.admission_competition_catalog%rowtype;
  target_id uuid;
  target_name text;
  target_status text;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select student.* into target_student
  from public.students student
  join public.contact_book_profiles profile on profile.id = student.profile_id
  where student.profile_id = auth.uid()
    and student.is_active
    and profile.approval_status = 'approved'
    and profile.is_active;
  if not found then raise exception 'student_required' using errcode = '42501'; end if;

  insert into public.admission_self_checks (student_id, class_id)
  values (target_student.id, target_student.class_id)
  on conflict (student_id) do update set updated_at = admission_self_checks.updated_at
  returning id into target_check_id;

  if nullif(trim(coalesce(p_catalog_code, '')), '') is not null then
    select catalog.* into target_catalog
    from public.admission_competition_catalog catalog
    where catalog.code = trim(p_catalog_code) and catalog.is_active;
    if not found or target_catalog.tier <> p_tier then raise exception 'invalid_competition'; end if;
    target_name := target_catalog.name;
    target_status := 'listed';
  else
    target_name := trim(coalesce(p_custom_name, ''));
    if length(target_name) not between 2 and 200 then raise exception 'invalid_competition'; end if;
    target_status := 'pending';
  end if;

  if p_school_year not between 100 and 999
    or p_tier not in ('international', 'national', 'county')
    or p_team_scale not in ('individual', 'team_4_19', 'team_20_plus')
    or (p_tier = 'international' and p_award_level <> 'first_to_fourth')
    or (p_tier = 'national' and p_award_level not in ('first', 'second', 'third', 'fourth_or_selected'))
    or (p_tier = 'county' and p_award_level not in ('first', 'second', 'third', 'fourth_to_sixth'))
    or length(trim(coalesce(p_competition_detail, ''))) > 300 then
    raise exception 'invalid_competition';
  end if;

  if p_entry_id is not null and not exists (
    select 1 from public.admission_competition_entries entry
    where entry.id = p_entry_id and entry.student_id = target_student.id
  ) then
    raise exception 'invalid_competition' using errcode = '42501';
  end if;

  insert into public.admission_competition_entries (
    id, self_check_id, student_id, class_id,
    catalog_id, catalog_code, competition_name, competition_detail,
    school_year, tier, award_level, team_scale, review_status,
    reviewed_by, reviewed_at
  ) values (
    coalesce(p_entry_id, gen_random_uuid()), target_check_id, target_student.id, target_student.class_id,
    target_catalog.id, target_catalog.code, target_name, trim(coalesce(p_competition_detail, '')),
    p_school_year, p_tier, p_award_level, p_team_scale, target_status,
    null, null
  )
  on conflict (id) do update
  set catalog_id = excluded.catalog_id,
      catalog_code = excluded.catalog_code,
      competition_name = excluded.competition_name,
      competition_detail = excluded.competition_detail,
      school_year = excluded.school_year,
      tier = excluded.tier,
      award_level = excluded.award_level,
      team_scale = excluded.team_scale,
      review_status = excluded.review_status,
      reviewed_by = null,
      reviewed_at = null,
      updated_at = now()
  returning id into target_id;

  update public.admission_self_checks
  set review_status = 'self_reported', reviewed_by = null, reviewed_at = null, updated_at = now()
  where id = target_check_id;

  return target_id;
exception
  when check_violation or invalid_text_representation or numeric_value_out_of_range then
    raise exception 'invalid_competition';
end;
$$;

create or replace function public.delete_my_admission_competition(p_entry_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  delete from public.admission_competition_entries entry
  where entry.id = p_entry_id
    and public.is_student_self(entry.student_id);
  if not found then raise exception 'invalid_competition' using errcode = '42501'; end if;
end;
$$;

create or replace function public.admin_review_admission_self_check(
  p_self_check_id uuid,
  p_review_status text,
  p_admin_note text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_class_id uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select class_id into target_class_id
  from public.admission_self_checks
  where id = p_self_check_id;
  if target_class_id is null or not public.can_manage_class(target_class_id) then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if p_review_status not in ('reviewed', 'needs_info')
    or length(trim(coalesce(p_admin_note, ''))) > 1000 then
    raise exception 'invalid_review';
  end if;
  update public.admission_self_checks
  set review_status = p_review_status,
      admin_note = trim(coalesce(p_admin_note, '')),
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      updated_at = now()
  where id = p_self_check_id;
end;
$$;

create or replace function public.admin_review_admission_competition(
  p_entry_id uuid,
  p_review_status text,
  p_admin_note text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_class_id uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select class_id into target_class_id
  from public.admission_competition_entries
  where id = p_entry_id;
  if target_class_id is null or not public.can_manage_class(target_class_id) then
    raise exception 'permission_denied' using errcode = '42501';
  end if;
  if p_review_status not in ('approved', 'rejected')
    or length(trim(coalesce(p_admin_note, ''))) > 1000 then
    raise exception 'invalid_review';
  end if;
  update public.admission_competition_entries
  set review_status = p_review_status,
      admin_note = trim(coalesce(p_admin_note, '')),
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      updated_at = now()
  where id = p_entry_id;
end;
$$;

revoke all on function public.save_my_admission_self_check(jsonb) from public, anon, authenticated;
revoke all on function public.save_my_admission_competition(uuid, text, text, text, smallint, text, text, text) from public, anon, authenticated;
revoke all on function public.delete_my_admission_competition(uuid) from public, anon, authenticated;
revoke all on function public.admin_review_admission_self_check(uuid, text, text) from public, anon, authenticated;
revoke all on function public.admin_review_admission_competition(uuid, text, text) from public, anon, authenticated;
grant execute on function public.save_my_admission_self_check(jsonb) to authenticated;
grant execute on function public.save_my_admission_competition(uuid, text, text, text, smallint, text, text, text) to authenticated;
grant execute on function public.delete_my_admission_competition(uuid) to authenticated;
grant execute on function public.admin_review_admission_self_check(uuid, text, text) to authenticated;
grant execute on function public.admin_review_admission_competition(uuid, text, text) to authenticated;

commit;
