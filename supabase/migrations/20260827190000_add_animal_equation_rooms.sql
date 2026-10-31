-- 根式馬戲團：第一階段即時房間、私人手牌與伺服器發牌。
-- 出牌、抓錯與功能牌判定將以後續 migration 擴充，不開放用戶直接更改分數。

create table if not exists public.animal_equation_rooms (
  id uuid primary key default gen_random_uuid(),
  room_code text not null check (room_code ~ '^[0-9]{4}$'),
  host_profile_id uuid not null references public.contact_book_profiles(id) on delete restrict,
  status text not null default 'lobby' check (status in ('lobby', 'playing', 'finished', 'closed')),
  current_player_id uuid,
  turn_number integer not null default 0,
  turn_deadline timestamptz,
  winner_player_id uuid,
  version bigint not null default 1,
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists animal_equation_active_room_code_unique
  on public.animal_equation_rooms(room_code)
  where status not in ('finished', 'closed');

create table if not exists public.animal_equation_players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.animal_equation_rooms(id) on delete cascade,
  profile_id uuid not null references public.contact_book_profiles(id) on delete restrict,
  display_name text not null check (char_length(display_name) between 1 and 10),
  seat_number smallint not null check (seat_number between 1 and 4),
  animal_score integer not null default 0,
  animal_count smallint not null default 0,
  judgement_stars integer not null default 0,
  last_seen_at timestamptz not null default now(),
  joined_at timestamptz not null default now(),
  unique (room_id, profile_id),
  unique (room_id, seat_number)
);

alter table public.animal_equation_rooms
  drop constraint if exists animal_equation_rooms_current_player_id_fkey;
alter table public.animal_equation_rooms
  add constraint animal_equation_rooms_current_player_id_fkey
  foreign key (current_player_id) references public.animal_equation_players(id) on delete set null;

alter table public.animal_equation_rooms
  drop constraint if exists animal_equation_rooms_winner_player_id_fkey;
alter table public.animal_equation_rooms
  add constraint animal_equation_rooms_winner_player_id_fkey
  foreign key (winner_player_id) references public.animal_equation_players(id) on delete set null;

create table if not exists public.animal_equation_cards (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.animal_equation_rooms(id) on delete cascade,
  card_type text not null check (card_type in ('radical', 'function')),
  card_code text not null,
  label text not null,
  coefficient numeric,
  radicand numeric,
  variable_code text,
  function_code text,
  location text not null default 'deck' check (location in ('deck', 'hand', 'discard')),
  owner_player_id uuid references public.animal_equation_players(id) on delete set null,
  deck_order integer not null default 0,
  created_at timestamptz not null default now(),
  constraint animal_equation_radical_values check (
    (card_type = 'radical' and function_code is null and (
      (coefficient is not null and radicand is not null and variable_code is null)
      or (coefficient is null and variable_code = 'n' and (radicand is null or radicand in (2, 3, 6)))
    ))
    or (card_type = 'function' and coefficient is null and radicand is null and variable_code is null and function_code is not null)
  )
);

create table if not exists public.animal_equation_animals (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.animal_equation_rooms(id) on delete cascade,
  position smallint not null check (position between 1 and 16),
  animal_code text not null,
  animal_name text not null,
  score smallint not null check (score in (5, 10, 15, 20)),
  owner_player_id uuid references public.animal_equation_players(id) on delete set null,
  revealed boolean not null default false,
  unique (room_id, position)
);

alter table public.animal_equation_rooms enable row level security;
alter table public.animal_equation_players enable row level security;
alter table public.animal_equation_cards enable row level security;
alter table public.animal_equation_animals enable row level security;

create or replace function public.animal_equation_is_participant(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.animal_equation_players player
    where player.room_id = p_room_id and player.profile_id = auth.uid()
  );
$$;

drop policy if exists animal_equation_rooms_participant_read on public.animal_equation_rooms;
create policy animal_equation_rooms_participant_read on public.animal_equation_rooms
for select to authenticated using (public.animal_equation_is_participant(id));

drop policy if exists animal_equation_players_participant_read on public.animal_equation_players;
create policy animal_equation_players_participant_read on public.animal_equation_players
for select to authenticated using (public.animal_equation_is_participant(room_id));

-- 牌片與動物全部只能透過 security definer RPC 讀寫，避免繞過畫面偷看手牌或分數。

create or replace function public.animal_equation_snapshot(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  me_player public.animal_equation_players%rowtype;
  players_json jsonb;
  hand_json jsonb;
  animals_json jsonb;
begin
  select * into selected_room from public.animal_equation_rooms where id = p_room_id;
  if selected_room.id is null or not public.animal_equation_is_participant(p_room_id) then
    raise exception using errcode = '42501', message = 'animal_room_access_denied';
  end if;

  select * into me_player from public.animal_equation_players
  where room_id = p_room_id and profile_id = auth.uid();

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id,
    'displayName', p.display_name,
    'seatNumber', p.seat_number,
    'animalScore', p.animal_score,
    'animalCount', p.animal_count,
    'judgementStars', p.judgement_stars,
    'connected', p.last_seen_at >= now() - interval '30 seconds'
  ) order by p.seat_number), '[]'::jsonb)
  into players_json from public.animal_equation_players p where p.room_id = p_room_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'type', c.card_type,
    'code', c.card_code,
    'label', c.label,
    'coefficient', c.coefficient,
    'radicand', c.radicand,
    'variableCode', c.variable_code,
    'functionCode', c.function_code
  ) order by c.deck_order, c.created_at), '[]'::jsonb)
  into hand_json from public.animal_equation_cards c
  where c.room_id = p_room_id and c.location = 'hand' and c.owner_player_id = me_player.id;

  select coalesce(jsonb_agg(
    case when a.owner_player_id is null and not a.revealed then
      jsonb_build_object('id', a.id, 'position', a.position, 'revealed', false)
    else jsonb_build_object(
      'id', a.id, 'position', a.position, 'revealed', true,
      'code', a.animal_code, 'name', a.animal_name, 'score', a.score,
      'ownerPlayerId', a.owner_player_id
    ) end order by a.position
  ), '[]'::jsonb)
  into animals_json from public.animal_equation_animals a where a.room_id = p_room_id;

  return jsonb_build_object(
    'id', selected_room.id,
    'code', selected_room.room_code,
    'status', selected_room.status,
    'isHost', selected_room.host_profile_id = auth.uid(),
    'mePlayerId', me_player.id,
    'currentPlayerId', selected_room.current_player_id,
    'turnNumber', selected_room.turn_number,
    'turnDeadline', selected_room.turn_deadline,
    'winnerPlayerId', selected_room.winner_player_id,
    'version', selected_room.version,
    'players', players_json,
    'hand', hand_json,
    'animals', animals_json
  );
end;
$$;

create or replace function public.animal_equation_create(p_display_name text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_name text := trim(coalesce(p_display_name, ''));
  new_room_id uuid;
  new_code text;
  host_player_id uuid;
begin
  if auth.uid() is null or not exists (select 1 from public.contact_book_profiles where id = auth.uid()) then
    raise exception using errcode = '42501', message = 'approved_profile_required';
  end if;
  if char_length(normalized_name) not between 1 and 10 then
    raise exception using errcode = 'P0001', message = 'animal_nickname_invalid';
  end if;

  loop
    new_code := lpad((floor(random() * 10000))::integer::text, 4, '0');
    exit when not exists (
      select 1 from public.animal_equation_rooms
      where room_code = new_code and status not in ('finished', 'closed')
    );
  end loop;

  insert into public.animal_equation_rooms(room_code, host_profile_id)
  values (new_code, auth.uid()) returning id into new_room_id;
  insert into public.animal_equation_players(room_id, profile_id, display_name, seat_number)
  values (new_room_id, auth.uid(), normalized_name, 1) returning id into host_player_id;

  insert into public.animal_equation_animals(room_id, position, animal_code, animal_name, score)
  select new_room_id, row_number() over (order by random())::smallint, seed.code, seed.name, seed.score
  from (values
    ('deer','梅花鹿',20),('octopus','章魚',20),('sloth','樹懶',20),('beluga','白鯨',20),
    ('ostrich','鴕鳥',15),('poodle','紅貴賓',15),('tabby','虎斑貓',15),('dolphin','海豚',15),
    ('beaver','海狸',10),('wallaby','矮袋鼠',10),('pig','粉紅豬',10),('goldfish','金魚',10),
    ('chihuahua','吉娃娃',5),('fox','狐狸',5),('maltese','馬爾濟斯',5),('corgi','柯基犬',5)
  ) as seed(code,name,score);

  insert into public.animal_equation_cards(
    room_id, card_type, card_code, label, coefficient, radicand, variable_code, deck_order
  )
  select new_room_id, 'radical', seed.code, seed.label, seed.coefficient, seed.radicand, seed.variable_code,
    row_number() over (order by random())::integer
  from (values
    ('sqrt1','√1',1::numeric,1::numeric,null::text,3),('sqrt4','√4',1,4,null,3),
    ('sqrt9','√9',1,9,null,3),('sqrt25','√25',1,25,null,3),('n','n',null,null,'n',6),
    ('sqrt2','√2',1,2,null,3),('sqrt8','√8',1,8,null,3),('sqrt18','√18',1,18,null,3),
    ('sqrt50','√50',1,50,null,3),('nsqrt2','n√2',null,2,'n',6),
    ('sqrt3','√3',1,3,null,3),('sqrt12','√12',1,12,null,3),('sqrt27','√27',1,27,null,3),
    ('sqrt75','√75',1,75,null,3),('nsqrt3','n√3',null,3,'n',6),
    ('sqrt6','√6',1,6,null,3),('sqrt24','√24',1,24,null,3),('sqrt54','√54',1,54,null,3),
    ('sqrt96','√96',1,96,null,3),('nsqrt6','n√6',null,6,'n',6)
  ) as seed(code,label,coefficient,radicand,variable_code,quantity)
  cross join lateral generate_series(1, seed.quantity);

  insert into public.animal_equation_cards(
    room_id, card_type, card_code, label, function_code, deck_order
  )
  select new_room_id, 'function', seed.code, seed.label, seed.code,
    1000 + row_number() over (order by random())::integer
  from (values
    ('tame','馴化',14),('accuse','指控',4),('clarify','澄清',4),
    ('tempt','誘惑',3),('gender_error','性別錯誤',3)
  ) as seed(code,label,quantity)
  cross join lateral generate_series(1, seed.quantity);

  return public.animal_equation_snapshot(new_room_id);
end;
$$;

create or replace function public.animal_equation_join(p_room_code text, p_display_name text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_code text := trim(coalesce(p_room_code, ''));
  normalized_name text := trim(coalesce(p_display_name, ''));
  selected_room public.animal_equation_rooms%rowtype;
  selected_seat smallint;
begin
  if auth.uid() is null or not exists (select 1 from public.contact_book_profiles where id = auth.uid()) then
    raise exception using errcode = '42501', message = 'approved_profile_required';
  end if;
  if normalized_code !~ '^[0-9]{4}$' then
    raise exception using errcode = 'P0001', message = 'animal_room_not_found';
  end if;
  if char_length(normalized_name) not between 1 and 10 then
    raise exception using errcode = 'P0001', message = 'animal_nickname_invalid';
  end if;

  select * into selected_room from public.animal_equation_rooms
  where room_code = normalized_code and status not in ('finished', 'closed') for update;
  if selected_room.id is null then raise exception using errcode = 'P0001', message = 'animal_room_not_found'; end if;

  if exists (select 1 from public.animal_equation_players where room_id = selected_room.id and profile_id = auth.uid()) then
    update public.animal_equation_players set display_name = normalized_name, last_seen_at = now()
    where room_id = selected_room.id and profile_id = auth.uid();
    return public.animal_equation_snapshot(selected_room.id);
  end if;
  if selected_room.status <> 'lobby' then raise exception using errcode = 'P0001', message = 'animal_room_started'; end if;

  select seat into selected_seat from generate_series(1,4) seat
  where not exists (
    select 1 from public.animal_equation_players p
    where p.room_id = selected_room.id and p.seat_number = seat
  ) order by seat limit 1;
  if selected_seat is null then raise exception using errcode = 'P0001', message = 'animal_room_full'; end if;

  insert into public.animal_equation_players(room_id, profile_id, display_name, seat_number)
  values (selected_room.id, auth.uid(), normalized_name, selected_seat);
  update public.animal_equation_rooms set version = version + 1, updated_at = now() where id = selected_room.id;
  return public.animal_equation_snapshot(selected_room.id);
end;
$$;

create or replace function public.animal_equation_start(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  player_count integer;
  player_row record;
  first_player_id uuid;
begin
  select * into selected_room from public.animal_equation_rooms where id = p_room_id for update;
  if selected_room.id is null or selected_room.host_profile_id <> auth.uid() then
    raise exception using errcode = '42501', message = 'animal_host_required';
  end if;
  if selected_room.status <> 'lobby' then raise exception using errcode = 'P0001', message = 'animal_room_started'; end if;
  select count(*) into player_count from public.animal_equation_players where room_id = p_room_id;
  if player_count <> 4 then raise exception using errcode = 'P0001', message = 'animal_players_incomplete'; end if;

  -- 開局時重新洗牌，並依隨機順序每人發 6 張。
  with shuffled as (
    select id, row_number() over (order by random())::integer as new_order
    from public.animal_equation_cards where room_id = p_room_id
  )
  update public.animal_equation_cards c set deck_order = shuffled.new_order
  from shuffled where c.id = shuffled.id;

  for player_row in select id from public.animal_equation_players where room_id = p_room_id order by seat_number loop
    update public.animal_equation_cards set location = 'hand', owner_player_id = player_row.id
    where id in (
      select id from public.animal_equation_cards
      where room_id = p_room_id and location = 'deck'
      order by deck_order limit 6
    );
  end loop;

  select id into first_player_id from public.animal_equation_players
  where room_id = p_room_id order by random() limit 1;
  update public.animal_equation_rooms set
    status = 'playing', current_player_id = first_player_id, turn_number = 1,
    turn_deadline = now() + interval '90 seconds', started_at = now(),
    version = version + 1, updated_at = now()
  where id = p_room_id;
  return public.animal_equation_snapshot(p_room_id);
end;
$$;

create or replace function public.animal_equation_heartbeat(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.animal_equation_players set last_seen_at = now()
  where room_id = p_room_id and profile_id = auth.uid();
  if not found then raise exception using errcode = '42501', message = 'animal_room_access_denied'; end if;
  return public.animal_equation_snapshot(p_room_id);
end;
$$;

grant execute on function public.animal_equation_snapshot(uuid) to authenticated;
grant execute on function public.animal_equation_create(text) to authenticated;
grant execute on function public.animal_equation_join(text,text) to authenticated;
grant execute on function public.animal_equation_start(uuid) to authenticated;
grant execute on function public.animal_equation_heartbeat(uuid) to authenticated;

do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'animal_equation_rooms'
  ) then alter publication supabase_realtime add table public.animal_equation_rooms; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'animal_equation_players'
  ) then alter publication supabase_realtime add table public.animal_equation_players; end if;
end $$;
