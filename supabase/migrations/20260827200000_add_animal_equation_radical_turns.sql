-- 根式馬戲團第二階段：根式出牌、每張 n 獨立代入正整數、8 秒抓錯與伺服器計分。

alter table public.animal_equation_rooms
  drop constraint if exists animal_equation_rooms_status_check;
alter table public.animal_equation_rooms
  add constraint animal_equation_rooms_status_check
  check (status in ('lobby', 'playing', 'review', 'finished', 'closed'));

alter table public.animal_equation_rooms
  add column if not exists pending_play_id uuid,
  add column if not exists last_result jsonb;

create table if not exists public.animal_equation_plays (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.animal_equation_rooms(id) on delete cascade,
  player_id uuid not null references public.animal_equation_players(id) on delete cascade,
  turn_number integer not null,
  play_mode text not null check (play_mode in ('single', 'same_family', 'equation')),
  selected_card_ids uuid[] not null,
  left_expression jsonb,
  right_expression jsonb,
  variable_values jsonb not null default '{}'::jsonb,
  is_valid boolean not null,
  challenger_player_id uuid references public.animal_equation_players(id) on delete set null,
  review_deadline timestamptz,
  submitted_at timestamptz not null default now(),
  resolved_at timestamptz,
  result_code text check (result_code in ('valid', 'invalid', 'caught', 'false_challenge')),
  unique (room_id, turn_number)
);

alter table public.animal_equation_rooms
  drop constraint if exists animal_equation_rooms_pending_play_id_fkey;
alter table public.animal_equation_rooms
  add constraint animal_equation_rooms_pending_play_id_fkey
  foreign key (pending_play_id) references public.animal_equation_plays(id) on delete set null;

alter table public.animal_equation_plays enable row level security;

create or replace function public.animal_equation_squarefree_part(p_value integer)
returns integer
language plpgsql
immutable
set search_path = public
as $$
declare
  remaining integer := p_value;
  factor integer := 2;
begin
  if remaining is null or remaining <= 0 then return null; end if;
  while factor * factor <= remaining loop
    while mod(remaining, factor * factor) = 0 loop
      remaining := remaining / (factor * factor);
    end loop;
    factor := factor + 1;
  end loop;
  return remaining;
end;
$$;

create or replace function public.animal_equation_collect_expression_cards(p_node jsonb)
returns uuid[]
language plpgsql
immutable
set search_path = public
as $$
declare
  node_type text := p_node ->> 'type';
  selected_id uuid;
begin
  if p_node is null then raise exception using errcode = 'P0001', message = 'animal_expression_incomplete'; end if;
  if node_type = 'card' then
    begin
      selected_id := (p_node ->> 'cardId')::uuid;
    exception when others then
      raise exception using errcode = 'P0001', message = 'animal_expression_incomplete';
    end;
    return array[selected_id];
  end if;
  if node_type <> 'operation' or (p_node ->> 'operator') not in ('+', '-', '*', '/') then
    raise exception using errcode = 'P0001', message = 'animal_expression_operator_invalid';
  end if;
  return public.animal_equation_collect_expression_cards(p_node -> 'left')
    || public.animal_equation_collect_expression_cards(p_node -> 'right');
end;
$$;

create or replace function public.animal_equation_evaluate_expression(
  p_node jsonb,
  p_room_id uuid,
  p_player_id uuid,
  p_variable_values jsonb
)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  node_type text := p_node ->> 'type';
  selected_card public.animal_equation_cards%rowtype;
  selected_id uuid;
  left_value numeric;
  right_value numeric;
  variable_text text;
  variable_number numeric;
begin
  if node_type = 'card' then
    begin
      selected_id := (p_node ->> 'cardId')::uuid;
    exception when others then
      raise exception using errcode = 'P0001', message = 'animal_expression_incomplete';
    end;
    select * into selected_card from public.animal_equation_cards
    where id = selected_id and room_id = p_room_id and owner_player_id = p_player_id
      and location = 'hand' and card_type = 'radical';
    if selected_card.id is null then raise exception using errcode = 'P0001', message = 'animal_card_not_in_hand'; end if;

    if selected_card.variable_code = 'n' then
      variable_text := p_variable_values ->> selected_card.id::text;
      if variable_text is null or variable_text !~ '^[1-9][0-9]*$' then
        raise exception using errcode = 'P0001', message = 'animal_variable_positive_integer_required';
      end if;
      variable_number := variable_text::numeric;
      return variable_number * case when selected_card.radicand is null then 1 else sqrt(selected_card.radicand) end;
    end if;
    return selected_card.coefficient * sqrt(selected_card.radicand);
  end if;

  if node_type <> 'operation' or (p_node ->> 'operator') not in ('+', '-', '*', '/') then
    raise exception using errcode = 'P0001', message = 'animal_expression_operator_invalid';
  end if;
  left_value := public.animal_equation_evaluate_expression(p_node -> 'left', p_room_id, p_player_id, p_variable_values);
  right_value := public.animal_equation_evaluate_expression(p_node -> 'right', p_room_id, p_player_id, p_variable_values);
  if (p_node ->> 'operator') = '+' then return left_value + right_value; end if;
  if (p_node ->> 'operator') = '-' then return left_value - right_value; end if;
  if (p_node ->> 'operator') = '*' then return left_value * right_value; end if;
  if abs(right_value) < 0.000000000001 then raise exception using errcode = 'P0001', message = 'animal_expression_division_by_zero'; end if;
  return left_value / right_value;
end;
$$;

create or replace function public.animal_equation_refill_hand(p_room_id uuid, p_player_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  hand_count integer;
  need_count integer;
  deck_count integer;
begin
  select count(*) into hand_count from public.animal_equation_cards
  where room_id = p_room_id and owner_player_id = p_player_id and location = 'hand';
  need_count := greatest(0, 6 - hand_count);
  if need_count = 0 then return; end if;
  select count(*) into deck_count from public.animal_equation_cards where room_id = p_room_id and location = 'deck';
  if deck_count < need_count then
    with shuffled as (
      select id, row_number() over (order by random())::integer as new_order
      from public.animal_equation_cards where room_id = p_room_id and location = 'discard'
    )
    update public.animal_equation_cards c
      set location = 'deck', owner_player_id = null, deck_order = shuffled.new_order
    from shuffled where c.id = shuffled.id;
  end if;
  update public.animal_equation_cards set location = 'hand', owner_player_id = p_player_id
  where id in (
    select id from public.animal_equation_cards
    where room_id = p_room_id and location = 'deck'
    order by deck_order, created_at limit need_count
  );
end;
$$;

create or replace function public.animal_equation_next_player(p_room_id uuid, p_current_player_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  current_seat smallint;
  next_id uuid;
begin
  select seat_number into current_seat from public.animal_equation_players where id = p_current_player_id and room_id = p_room_id;
  select id into next_id from public.animal_equation_players
  where room_id = p_room_id and seat_number > current_seat order by seat_number limit 1;
  if next_id is null then
    select id into next_id from public.animal_equation_players where room_id = p_room_id order by seat_number limit 1;
  end if;
  return next_id;
end;
$$;

create or replace function public.animal_equation_resolve_pending(p_room_id uuid, p_challenger_player_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  selected_play public.animal_equation_plays%rowtype;
  next_player_id uuid;
  resolved_code text;
  star_delta integer := 0;
begin
  select * into selected_room from public.animal_equation_rooms where id = p_room_id for update;
  select * into selected_play from public.animal_equation_plays where id = selected_room.pending_play_id for update;
  if selected_play.id is null or selected_play.resolved_at is not null then
    raise exception using errcode = 'P0001', message = 'animal_review_closed';
  end if;
  if p_challenger_player_id is not null then
    if p_challenger_player_id = selected_play.player_id or not exists (
      select 1 from public.animal_equation_players where id = p_challenger_player_id and room_id = p_room_id
    ) then raise exception using errcode = '42501', message = 'animal_challenge_not_allowed'; end if;
    star_delta := case when selected_play.is_valid then -1 else 3 end;
    update public.animal_equation_players
      set judgement_stars = judgement_stars + star_delta
    where id = p_challenger_player_id;
  end if;

  if selected_play.is_valid then
    update public.animal_equation_cards set location = 'discard', owner_player_id = null
    where room_id = p_room_id and id = any(selected_play.selected_card_ids)
      and owner_player_id = selected_play.player_id and location = 'hand';
    perform public.animal_equation_refill_hand(p_room_id, selected_play.player_id);
  end if;

  resolved_code := case
    when p_challenger_player_id is not null and selected_play.is_valid then 'false_challenge'
    when p_challenger_player_id is not null and not selected_play.is_valid then 'caught'
    when selected_play.is_valid then 'valid'
    else 'invalid'
  end;
  update public.animal_equation_plays set
    challenger_player_id = p_challenger_player_id,
    result_code = resolved_code,
    resolved_at = now()
  where id = selected_play.id;

  next_player_id := public.animal_equation_next_player(p_room_id, selected_play.player_id);
  update public.animal_equation_rooms set
    status = 'playing', current_player_id = next_player_id, turn_number = turn_number + 1,
    turn_deadline = now() + interval '90 seconds', pending_play_id = null,
    last_result = jsonb_build_object(
      'type', 'radical', 'playerId', selected_play.player_id, 'result', resolved_code,
      'challengerPlayerId', p_challenger_player_id, 'starDelta', star_delta
    ),
    version = version + 1, updated_at = now()
  where id = p_room_id;
end;
$$;

create or replace function public.animal_equation_submit_radical(
  p_room_id uuid,
  p_play_mode text,
  p_selected_card_ids uuid[],
  p_left_expression jsonb default null,
  p_right_expression jsonb default null,
  p_variable_values jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  me_player public.animal_equation_players%rowtype;
  selected_count integer;
  owned_count integer;
  distinct_count integer;
  invalid_variable_count integer;
  family_count integer;
  used_ids uuid[];
  normalized_selected text[];
  normalized_used text[];
  left_value numeric;
  right_value numeric;
  difference numeric;
  scale numeric;
  play_valid boolean := false;
  new_play_id uuid;
  review_until timestamptz := now() + interval '8 seconds';
begin
  select * into selected_room from public.animal_equation_rooms where id = p_room_id for update;
  select * into me_player from public.animal_equation_players where room_id = p_room_id and profile_id = auth.uid();
  if selected_room.id is null or me_player.id is null then raise exception using errcode = '42501', message = 'animal_room_access_denied'; end if;
  if selected_room.status <> 'playing' or selected_room.current_player_id <> me_player.id then
    raise exception using errcode = 'P0001', message = 'animal_not_your_turn';
  end if;
  if selected_room.turn_deadline is not null and now() > selected_room.turn_deadline then
    raise exception using errcode = 'P0001', message = 'animal_turn_expired';
  end if;
  if p_play_mode not in ('single', 'same_family', 'equation') then
    raise exception using errcode = 'P0001', message = 'animal_play_mode_invalid';
  end if;
  selected_count := coalesce(cardinality(p_selected_card_ids), 0);
  if selected_count not between 1 and 6 then raise exception using errcode = 'P0001', message = 'animal_card_count_invalid'; end if;
  select count(*), count(distinct card_id) into selected_count, distinct_count from unnest(p_selected_card_ids) card_id;
  if selected_count <> distinct_count then raise exception using errcode = 'P0001', message = 'animal_card_reused'; end if;
  select count(*) into owned_count from public.animal_equation_cards
  where id = any(p_selected_card_ids) and room_id = p_room_id and owner_player_id = me_player.id
    and location = 'hand' and card_type = 'radical';
  if owned_count <> selected_count then raise exception using errcode = 'P0001', message = 'animal_card_not_in_hand'; end if;
  select count(*) into invalid_variable_count from public.animal_equation_cards c
  where c.id = any(p_selected_card_ids) and c.variable_code = 'n'
    and coalesce(p_variable_values ->> c.id::text, '') !~ '^[1-9][0-9]*$';
  if invalid_variable_count > 0 then
    raise exception using errcode = 'P0001', message = 'animal_variable_positive_integer_required';
  end if;

  if p_play_mode = 'single' then
    if selected_count <> 1 then raise exception using errcode = 'P0001', message = 'animal_single_requires_one'; end if;
    play_valid := true;
  elsif p_play_mode = 'same_family' then
    if selected_count <> 2 then raise exception using errcode = 'P0001', message = 'animal_family_requires_two'; end if;
    select count(distinct case
      when variable_code = 'n' and radicand is null then 1
      when variable_code = 'n' then radicand::integer
      else public.animal_equation_squarefree_part(radicand::integer)
    end) into family_count
    from public.animal_equation_cards where id = any(p_selected_card_ids);
    play_valid := family_count = 1;
  else
    if selected_count < 2 then raise exception using errcode = 'P0001', message = 'animal_equation_requires_two'; end if;
    used_ids := public.animal_equation_collect_expression_cards(p_left_expression)
      || public.animal_equation_collect_expression_cards(p_right_expression);
    select array_agg(id::text order by id::text) into normalized_selected from unnest(p_selected_card_ids) id;
    select array_agg(id::text order by id::text) into normalized_used from unnest(used_ids) id;
    if cardinality(used_ids) <> selected_count
      or (select count(distinct id) from unnest(used_ids) id) <> selected_count
      or normalized_used is distinct from normalized_selected then
      raise exception using errcode = 'P0001', message = 'animal_selected_cards_once';
    end if;
    left_value := public.animal_equation_evaluate_expression(p_left_expression, p_room_id, me_player.id, coalesce(p_variable_values, '{}'::jsonb));
    right_value := public.animal_equation_evaluate_expression(p_right_expression, p_room_id, me_player.id, coalesce(p_variable_values, '{}'::jsonb));
    difference := abs(left_value - right_value);
    scale := greatest(1, abs(left_value), abs(right_value));
    play_valid := difference <= scale * 0.000000001;
  end if;

  insert into public.animal_equation_plays(
    room_id, player_id, turn_number, play_mode, selected_card_ids,
    left_expression, right_expression, variable_values, is_valid, review_deadline
  ) values (
    p_room_id, me_player.id, selected_room.turn_number, p_play_mode, p_selected_card_ids,
    p_left_expression, p_right_expression, coalesce(p_variable_values, '{}'::jsonb), play_valid,
    case when p_play_mode = 'single' then now() else review_until end
  ) returning id into new_play_id;

  update public.animal_equation_rooms set
    status = 'review', pending_play_id = new_play_id,
    version = version + 1, updated_at = now()
  where id = p_room_id;
  if p_play_mode = 'single' then perform public.animal_equation_resolve_pending(p_room_id, null); end if;
  return public.animal_equation_snapshot(p_room_id);
end;
$$;

create or replace function public.animal_equation_challenge(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  selected_play public.animal_equation_plays%rowtype;
  me_player_id uuid;
begin
  select * into selected_room from public.animal_equation_rooms where id = p_room_id for update;
  select id into me_player_id from public.animal_equation_players where room_id = p_room_id and profile_id = auth.uid();
  select * into selected_play from public.animal_equation_plays where id = selected_room.pending_play_id;
  if me_player_id is null then raise exception using errcode = '42501', message = 'animal_room_access_denied'; end if;
  if selected_room.status <> 'review' or selected_play.id is null or now() > selected_play.review_deadline then
    raise exception using errcode = 'P0001', message = 'animal_review_closed';
  end if;
  perform public.animal_equation_resolve_pending(p_room_id, me_player_id);
  return public.animal_equation_snapshot(p_room_id);
end;
$$;

create or replace function public.animal_equation_advance(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  selected_play public.animal_equation_plays%rowtype;
  next_player_id uuid;
begin
  if not public.animal_equation_is_participant(p_room_id) then
    raise exception using errcode = '42501', message = 'animal_room_access_denied';
  end if;
  select * into selected_room from public.animal_equation_rooms where id = p_room_id for update;
  if selected_room.status = 'review' then
    select * into selected_play from public.animal_equation_plays where id = selected_room.pending_play_id;
    if selected_play.review_deadline <= now() then perform public.animal_equation_resolve_pending(p_room_id, null); end if;
  elsif selected_room.status = 'playing' and selected_room.turn_deadline <= now() then
    next_player_id := public.animal_equation_next_player(p_room_id, selected_room.current_player_id);
    update public.animal_equation_rooms set
      current_player_id = next_player_id, turn_number = turn_number + 1,
      turn_deadline = now() + interval '90 seconds',
      last_result = jsonb_build_object('type', 'timeout', 'playerId', selected_room.current_player_id),
      version = version + 1, updated_at = now()
    where id = p_room_id;
  end if;
  return public.animal_equation_snapshot(p_room_id);
end;
$$;

-- 快照不回傳 is_valid，其他玩家必須自己判斷是否抓錯。
create or replace function public.animal_equation_snapshot(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  me_player public.animal_equation_players%rowtype;
  selected_play public.animal_equation_plays%rowtype;
  players_json jsonb;
  hand_json jsonb;
  animals_json jsonb;
  pending_json jsonb;
  selected_cards_json jsonb;
begin
  select * into selected_room from public.animal_equation_rooms where id = p_room_id;
  if selected_room.id is null or not public.animal_equation_is_participant(p_room_id) then
    raise exception using errcode = '42501', message = 'animal_room_access_denied';
  end if;
  select * into me_player from public.animal_equation_players where room_id = p_room_id and profile_id = auth.uid();
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id, 'displayName', p.display_name, 'seatNumber', p.seat_number,
    'animalScore', p.animal_score, 'animalCount', p.animal_count,
    'judgementStars', p.judgement_stars, 'connected', p.last_seen_at >= now() - interval '30 seconds'
  ) order by p.seat_number), '[]'::jsonb) into players_json
  from public.animal_equation_players p where p.room_id = p_room_id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id, 'type', c.card_type, 'code', c.card_code, 'label', c.label,
    'coefficient', c.coefficient, 'radicand', c.radicand,
    'variableCode', c.variable_code, 'functionCode', c.function_code
  ) order by c.deck_order, c.created_at), '[]'::jsonb) into hand_json
  from public.animal_equation_cards c
  where c.room_id = p_room_id and c.location = 'hand' and c.owner_player_id = me_player.id;
  select coalesce(jsonb_agg(case when a.owner_player_id is null and not a.revealed then
    jsonb_build_object('id', a.id, 'position', a.position, 'revealed', false)
  else jsonb_build_object('id', a.id, 'position', a.position, 'revealed', true,
    'code', a.animal_code, 'name', a.animal_name, 'score', a.score, 'ownerPlayerId', a.owner_player_id)
  end order by a.position), '[]'::jsonb) into animals_json
  from public.animal_equation_animals a where a.room_id = p_room_id;

  if selected_room.pending_play_id is not null then
    select * into selected_play from public.animal_equation_plays where id = selected_room.pending_play_id;
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', c.id, 'label', c.label, 'variableValue', selected_play.variable_values ->> c.id::text
    ) order by array_position(selected_play.selected_card_ids, c.id)), '[]'::jsonb)
    into selected_cards_json from public.animal_equation_cards c where c.id = any(selected_play.selected_card_ids);
    pending_json := jsonb_build_object(
      'id', selected_play.id, 'playerId', selected_play.player_id, 'mode', selected_play.play_mode,
      'selectedCards', selected_cards_json, 'left', selected_play.left_expression,
      'right', selected_play.right_expression, 'reviewDeadline', selected_play.review_deadline
    );
  end if;

  return jsonb_build_object(
    'id', selected_room.id, 'code', selected_room.room_code, 'status', selected_room.status,
    'isHost', selected_room.host_profile_id = auth.uid(), 'mePlayerId', me_player.id,
    'currentPlayerId', selected_room.current_player_id, 'turnNumber', selected_room.turn_number,
    'turnDeadline', selected_room.turn_deadline, 'winnerPlayerId', selected_room.winner_player_id,
    'version', selected_room.version, 'players', players_json, 'hand', hand_json,
    'animals', animals_json, 'pendingPlay', pending_json, 'lastResult', selected_room.last_result
  );
end;
$$;

grant execute on function public.animal_equation_submit_radical(uuid,text,uuid[],jsonb,jsonb,jsonb) to authenticated;
grant execute on function public.animal_equation_challenge(uuid) to authenticated;
grant execute on function public.animal_equation_advance(uuid) to authenticated;
