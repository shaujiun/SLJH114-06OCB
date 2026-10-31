-- 根式馬戲團：功能牌、反應牌、動物得分與勝負判定。

alter table public.animal_equation_rooms
  drop constraint if exists animal_equation_rooms_status_check;
alter table public.animal_equation_rooms
  add constraint animal_equation_rooms_status_check
  check (status in ('lobby', 'playing', 'review', 'reaction', 'finished', 'closed'));

create table if not exists public.animal_equation_function_actions (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.animal_equation_rooms(id) on delete cascade,
  actor_player_id uuid not null references public.animal_equation_players(id) on delete cascade,
  function_card_id uuid not null references public.animal_equation_cards(id) on delete restrict,
  function_code text not null check (function_code in ('tame', 'accuse', 'tempt')),
  target_animal_id uuid not null references public.animal_equation_animals(id) on delete restrict,
  target_player_id uuid references public.animal_equation_players(id) on delete cascade,
  defense_card_id uuid references public.animal_equation_cards(id) on delete set null,
  defense_code text check (defense_code is null or defense_code in ('clarify', 'gender_error')),
  response_deadline timestamptz,
  result_code text check (result_code is null or result_code in (
    'tame_success', 'accuse_success', 'accuse_blocked', 'tempt_success', 'tempt_blocked'
  )),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.animal_equation_rooms
  add column if not exists pending_function_action_id uuid;
alter table public.animal_equation_rooms
  drop constraint if exists animal_equation_rooms_pending_function_action_id_fkey;
alter table public.animal_equation_rooms
  add constraint animal_equation_rooms_pending_function_action_id_fkey
  foreign key (pending_function_action_id) references public.animal_equation_function_actions(id) on delete set null;

alter table public.animal_equation_function_actions enable row level security;

create or replace function public.animal_equation_recalculate_scores(p_room_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.animal_equation_players player set
    animal_count = score_data.animal_count,
    animal_score = score_data.animal_score
  from (
    select p.id,
      count(a.id)::smallint as animal_count,
      coalesce(sum(a.score), 0)::integer as animal_score
    from public.animal_equation_players p
    left join public.animal_equation_animals a
      on a.room_id = p.room_id and a.owner_player_id = p.id and a.revealed
    where p.room_id = p_room_id
    group by p.id
  ) score_data
  where player.id = score_data.id;
$$;

create or replace function public.animal_equation_finish_function_turn(
  p_room_id uuid,
  p_actor_player_id uuid,
  p_action_id uuid,
  p_result_code text,
  p_defense_player_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  winner_id uuid;
  next_player_id uuid;
begin
  select * into selected_room from public.animal_equation_rooms where id = p_room_id for update;
  perform public.animal_equation_recalculate_scores(p_room_id);

  select p.id into winner_id
  from public.animal_equation_players p
  where p.room_id = p_room_id and (p.animal_count >= 4 or p.animal_score >= 40)
  order by case when p.id = p_actor_player_id then 0 else 1 end,
    p.animal_count desc, p.animal_score desc, p.judgement_stars desc, p.seat_number
  limit 1;

  if winner_id is not null then
    update public.animal_equation_rooms set
      status = 'finished', current_player_id = null, turn_deadline = null,
      winner_player_id = winner_id, pending_function_action_id = null,
      finished_at = now(),
      last_result = jsonb_build_object(
        'type', 'function', 'playerId', p_actor_player_id, 'result', p_result_code,
        'defensePlayerId', p_defense_player_id, 'winnerPlayerId', winner_id
      ),
      version = version + 1, updated_at = now()
    where id = p_room_id;
    return;
  end if;

  next_player_id := public.animal_equation_next_player(p_room_id, p_actor_player_id);
  update public.animal_equation_rooms set
    status = 'playing', current_player_id = next_player_id,
    turn_number = turn_number + 1, turn_deadline = now() + interval '90 seconds',
    pending_function_action_id = null,
    last_result = jsonb_build_object(
      'type', 'function', 'playerId', p_actor_player_id, 'result', p_result_code,
      'defensePlayerId', p_defense_player_id
    ),
    version = version + 1, updated_at = now()
  where id = p_room_id;
end;
$$;

create or replace function public.animal_equation_resolve_function_action(
  p_room_id uuid,
  p_defense_card_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  selected_action public.animal_equation_function_actions%rowtype;
  defense_card public.animal_equation_cards%rowtype;
  expected_defense text;
  resolved_code text;
begin
  select * into selected_room from public.animal_equation_rooms where id = p_room_id for update;
  select * into selected_action from public.animal_equation_function_actions
  where id = selected_room.pending_function_action_id for update;
  if selected_action.id is null or selected_action.resolved_at is not null then
    raise exception using errcode = 'P0001', message = 'animal_function_reaction_closed';
  end if;

  expected_defense := case selected_action.function_code
    when 'accuse' then 'clarify'
    when 'tempt' then 'gender_error'
    else null
  end;
  if p_defense_card_id is not null then
    select * into defense_card from public.animal_equation_cards
    where id = p_defense_card_id and room_id = p_room_id
      and owner_player_id = selected_action.target_player_id
      and location = 'hand' and card_type = 'function';
    if defense_card.id is null or defense_card.function_code <> expected_defense then
      raise exception using errcode = 'P0001', message = 'animal_defense_card_invalid';
    end if;
    update public.animal_equation_cards set location = 'discard', owner_player_id = null
    where id = defense_card.id;
  end if;

  if selected_action.function_code = 'accuse' then
    if p_defense_card_id is null then
      update public.animal_equation_animals set owner_player_id = null, revealed = false
      where id = selected_action.target_animal_id and room_id = p_room_id
        and owner_player_id = selected_action.target_player_id;
      resolved_code := 'accuse_success';
    else
      resolved_code := 'accuse_blocked';
    end if;
  elsif selected_action.function_code = 'tempt' then
    if p_defense_card_id is null then
      update public.animal_equation_animals set owner_player_id = selected_action.actor_player_id, revealed = true
      where id = selected_action.target_animal_id and room_id = p_room_id
        and owner_player_id = selected_action.target_player_id;
      resolved_code := 'tempt_success';
    else
      resolved_code := 'tempt_blocked';
    end if;
  else
    raise exception using errcode = 'P0001', message = 'animal_function_action_invalid';
  end if;

  update public.animal_equation_cards set location = 'discard', owner_player_id = null
  where id = selected_action.function_card_id and room_id = p_room_id
    and owner_player_id = selected_action.actor_player_id and location = 'hand';
  perform public.animal_equation_refill_hand(p_room_id, selected_action.actor_player_id);
  if p_defense_card_id is not null then
    perform public.animal_equation_refill_hand(p_room_id, selected_action.target_player_id);
  end if;

  update public.animal_equation_function_actions set
    defense_card_id = p_defense_card_id,
    defense_code = case when p_defense_card_id is null then null else expected_defense end,
    result_code = resolved_code, resolved_at = now()
  where id = selected_action.id;
  perform public.animal_equation_finish_function_turn(
    p_room_id, selected_action.actor_player_id, selected_action.id, resolved_code,
    case when p_defense_card_id is null then null else selected_action.target_player_id end
  );
end;
$$;

create or replace function public.animal_equation_submit_function(
  p_room_id uuid,
  p_function_card_id uuid,
  p_target_animal_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  me_player public.animal_equation_players%rowtype;
  selected_card public.animal_equation_cards%rowtype;
  selected_animal public.animal_equation_animals%rowtype;
  new_action_id uuid;
  resolved_code text;
begin
  select * into selected_room from public.animal_equation_rooms where id = p_room_id for update;
  select * into me_player from public.animal_equation_players
    where room_id = p_room_id and profile_id = auth.uid();
  if selected_room.id is null or me_player.id is null then
    raise exception using errcode = '42501', message = 'animal_room_access_denied';
  end if;
  if selected_room.status <> 'playing' or selected_room.current_player_id <> me_player.id then
    raise exception using errcode = 'P0001', message = 'animal_not_your_turn';
  end if;
  if selected_room.turn_deadline is not null and now() > selected_room.turn_deadline then
    raise exception using errcode = 'P0001', message = 'animal_turn_expired';
  end if;
  select * into selected_card from public.animal_equation_cards
  where id = p_function_card_id and room_id = p_room_id and owner_player_id = me_player.id
    and location = 'hand' and card_type = 'function';
  if selected_card.id is null then
    raise exception using errcode = 'P0001', message = 'animal_card_not_in_hand';
  end if;
  if selected_card.function_code in ('clarify', 'gender_error') then
    raise exception using errcode = 'P0001', message = 'animal_function_reactive_only';
  end if;
  select * into selected_animal from public.animal_equation_animals
  where id = p_target_animal_id and room_id = p_room_id for update;
  if selected_animal.id is null then
    raise exception using errcode = 'P0001', message = 'animal_target_invalid';
  end if;

  if selected_card.function_code = 'tame' then
    if selected_animal.revealed or selected_animal.owner_player_id is not null then
      raise exception using errcode = 'P0001', message = 'animal_tame_target_invalid';
    end if;
    update public.animal_equation_animals set owner_player_id = me_player.id, revealed = true
    where id = selected_animal.id;
    update public.animal_equation_cards set location = 'discard', owner_player_id = null
    where id = selected_card.id;
    insert into public.animal_equation_function_actions(
      room_id, actor_player_id, function_card_id, function_code,
      target_animal_id, result_code, resolved_at
    ) values (
      p_room_id, me_player.id, selected_card.id, 'tame',
      selected_animal.id, 'tame_success', now()
    ) returning id into new_action_id;
    perform public.animal_equation_refill_hand(p_room_id, me_player.id);
    perform public.animal_equation_finish_function_turn(
      p_room_id, me_player.id, new_action_id, 'tame_success', null
    );
    return public.animal_equation_snapshot(p_room_id);
  end if;

  if selected_animal.owner_player_id is null or not selected_animal.revealed
    or selected_animal.owner_player_id = me_player.id then
    raise exception using errcode = 'P0001', message = 'animal_opponent_target_required';
  end if;
  insert into public.animal_equation_function_actions(
    room_id, actor_player_id, function_card_id, function_code,
    target_animal_id, target_player_id, response_deadline
  ) values (
    p_room_id, me_player.id, selected_card.id, selected_card.function_code,
    selected_animal.id, selected_animal.owner_player_id, now() + interval '8 seconds'
  ) returning id into new_action_id;
  update public.animal_equation_rooms set
    status = 'reaction', pending_function_action_id = new_action_id,
    version = version + 1, updated_at = now()
  where id = p_room_id;
  return public.animal_equation_snapshot(p_room_id);
end;
$$;

create or replace function public.animal_equation_respond_function(
  p_room_id uuid,
  p_defense_card_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  selected_action public.animal_equation_function_actions%rowtype;
  me_player_id uuid;
begin
  select * into selected_room from public.animal_equation_rooms where id = p_room_id for update;
  select * into selected_action from public.animal_equation_function_actions
    where id = selected_room.pending_function_action_id;
  select id into me_player_id from public.animal_equation_players
    where room_id = p_room_id and profile_id = auth.uid();
  if me_player_id is null then
    raise exception using errcode = '42501', message = 'animal_room_access_denied';
  end if;
  if selected_room.status <> 'reaction' or selected_action.id is null
    or selected_action.resolved_at is not null or now() > selected_action.response_deadline then
    raise exception using errcode = 'P0001', message = 'animal_function_reaction_closed';
  end if;
  if selected_action.target_player_id <> me_player_id then
    raise exception using errcode = '42501', message = 'animal_function_target_only';
  end if;
  perform public.animal_equation_resolve_function_action(p_room_id, p_defense_card_id);
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
  selected_action public.animal_equation_function_actions%rowtype;
  next_player_id uuid;
begin
  if not public.animal_equation_is_participant(p_room_id) then
    raise exception using errcode = '42501', message = 'animal_room_access_denied';
  end if;
  select * into selected_room from public.animal_equation_rooms where id = p_room_id for update;
  if selected_room.status = 'review' then
    select * into selected_play from public.animal_equation_plays where id = selected_room.pending_play_id;
    if selected_play.review_deadline <= now() then
      perform public.animal_equation_resolve_pending(p_room_id, null);
    end if;
  elsif selected_room.status = 'reaction' then
    select * into selected_action from public.animal_equation_function_actions
      where id = selected_room.pending_function_action_id;
    if selected_action.response_deadline <= now() then
      perform public.animal_equation_resolve_function_action(p_room_id, null);
    end if;
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
  selected_action public.animal_equation_function_actions%rowtype;
  target_animal public.animal_equation_animals%rowtype;
  players_json jsonb;
  hand_json jsonb;
  animals_json jsonb;
  pending_json jsonb;
  pending_function_json jsonb;
  selected_cards_json jsonb;
begin
  select * into selected_room from public.animal_equation_rooms where id = p_room_id;
  if selected_room.id is null or not public.animal_equation_is_participant(p_room_id) then
    raise exception using errcode = '42501', message = 'animal_room_access_denied';
  end if;
  select * into me_player from public.animal_equation_players
    where room_id = p_room_id and profile_id = auth.uid();
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id, 'displayName', p.display_name, 'seatNumber', p.seat_number,
    'animalScore', p.animal_score, 'animalCount', p.animal_count,
    'judgementStars', p.judgement_stars,
    'connected', p.last_seen_at >= now() - interval '30 seconds'
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
  else jsonb_build_object(
    'id', a.id, 'position', a.position, 'revealed', true,
    'code', a.animal_code, 'name', a.animal_name, 'score', a.score,
    'ownerPlayerId', a.owner_player_id
  ) end order by a.position), '[]'::jsonb) into animals_json
  from public.animal_equation_animals a where a.room_id = p_room_id;

  if selected_room.pending_play_id is not null then
    select * into selected_play from public.animal_equation_plays where id = selected_room.pending_play_id;
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', c.id, 'label', c.label,
      'variableValue', selected_play.variable_values ->> c.id::text
    ) order by array_position(selected_play.selected_card_ids, c.id)), '[]'::jsonb)
    into selected_cards_json from public.animal_equation_cards c
    where c.id = any(selected_play.selected_card_ids);
    pending_json := jsonb_build_object(
      'id', selected_play.id, 'playerId', selected_play.player_id,
      'mode', selected_play.play_mode, 'selectedCards', selected_cards_json,
      'left', selected_play.left_expression, 'right', selected_play.right_expression,
      'reviewDeadline', selected_play.review_deadline
    );
  end if;

  if selected_room.pending_function_action_id is not null then
    select * into selected_action from public.animal_equation_function_actions
      where id = selected_room.pending_function_action_id;
    select * into target_animal from public.animal_equation_animals
      where id = selected_action.target_animal_id;
    pending_function_json := jsonb_build_object(
      'id', selected_action.id, 'actorPlayerId', selected_action.actor_player_id,
      'functionCode', selected_action.function_code,
      'targetPlayerId', selected_action.target_player_id,
      'targetAnimal', jsonb_build_object(
        'id', target_animal.id, 'position', target_animal.position,
        'code', target_animal.animal_code, 'name', target_animal.animal_name,
        'score', target_animal.score
      ),
      'responseDeadline', selected_action.response_deadline
    );
  end if;

  return jsonb_build_object(
    'id', selected_room.id, 'code', selected_room.room_code, 'status', selected_room.status,
    'isHost', selected_room.host_profile_id = auth.uid(), 'mePlayerId', me_player.id,
    'currentPlayerId', selected_room.current_player_id,
    'turnNumber', selected_room.turn_number, 'turnDeadline', selected_room.turn_deadline,
    'winnerPlayerId', selected_room.winner_player_id, 'version', selected_room.version,
    'players', players_json, 'hand', hand_json, 'animals', animals_json,
    'pendingPlay', pending_json, 'pendingFunction', pending_function_json,
    'lastResult', selected_room.last_result
  );
end;
$$;

revoke all on function public.animal_equation_recalculate_scores(uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_finish_function_turn(uuid,uuid,uuid,text,uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_resolve_function_action(uuid,uuid) from public, anon, authenticated;
grant execute on function public.animal_equation_submit_function(uuid,uuid,uuid) to authenticated;
grant execute on function public.animal_equation_respond_function(uuid,uuid) to authenticated;
grant execute on function public.animal_equation_advance(uuid) to authenticated;
