-- 根式馬戲團：1～4 位真人，空位由 AI 補滿；單人模式可列入每日任務。

alter table public.animal_equation_rooms
  add column if not exists human_player_limit smallint not null default 4
    check (human_player_limit between 1 and 4),
  add column if not exists ai_human_attack_round integer not null default -1;

alter table public.animal_equation_players
  alter column profile_id drop not null;
alter table public.animal_equation_players
  add column if not exists is_ai boolean not null default false,
  add column if not exists ai_accuracy numeric(4,3) not null default 0.8
    check (ai_accuracy between 0.6 and 0.8),
  add column if not exists valid_radical_plays integer not null default 0;
alter table public.animal_equation_players
  drop constraint if exists animal_equation_players_identity_check;
alter table public.animal_equation_players
  add constraint animal_equation_players_identity_check check (
    (is_ai and profile_id is null) or (not is_ai and profile_id is not null)
  );

create or replace function public.animal_equation_create_with_mode(
  p_display_name text,
  p_human_player_limit integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  created_room jsonb;
  new_room_id uuid;
begin
  if p_human_player_limit is null or p_human_player_limit not between 1 and 4 then
    raise exception using errcode = 'P0001', message = 'animal_human_count_invalid';
  end if;
  created_room := public.animal_equation_create(p_display_name);
  new_room_id := (created_room ->> 'id')::uuid;
  update public.animal_equation_rooms
  set human_player_limit = p_human_player_limit, version = version + 1, updated_at = now()
  where id = new_room_id;
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
  human_count integer;
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
  where room_code = normalized_code and status <> 'closed' for update;
  if selected_room.id is null then raise exception using errcode = 'P0001', message = 'animal_room_not_found'; end if;
  if exists (select 1 from public.animal_equation_players where room_id = selected_room.id and profile_id = auth.uid()) then
    update public.animal_equation_players set display_name = normalized_name, last_seen_at = now(), left_at = null
    where room_id = selected_room.id and profile_id = auth.uid();
    return public.animal_equation_snapshot(selected_room.id);
  end if;
  if selected_room.status <> 'lobby' then raise exception using errcode = 'P0001', message = 'animal_room_started'; end if;
  select count(*) into human_count from public.animal_equation_players
  where room_id = selected_room.id and not is_ai;
  if human_count >= selected_room.human_player_limit then
    raise exception using errcode = 'P0001', message = 'animal_human_slots_full';
  end if;
  select seat into selected_seat from generate_series(1,4) seat
  where not exists (select 1 from public.animal_equation_players p where p.room_id = selected_room.id and p.seat_number = seat)
  order by seat limit 1;
  insert into public.animal_equation_players(room_id, profile_id, display_name, seat_number, is_ai)
  values (selected_room.id, auth.uid(), normalized_name, selected_seat, false);
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
  human_count integer;
  player_row record;
  first_player_id uuid;
  seat smallint;
  ai_names text[] := array['AI 小狐','AI 海豚','AI 樹懶'];
  ai_index integer := 1;
begin
  select * into selected_room from public.animal_equation_rooms where id = p_room_id for update;
  if selected_room.id is null or selected_room.host_profile_id <> auth.uid() then
    raise exception using errcode = '42501', message = 'animal_host_required';
  end if;
  if selected_room.status <> 'lobby' then raise exception using errcode = 'P0001', message = 'animal_room_started'; end if;
  select count(*) into human_count from public.animal_equation_players where room_id = p_room_id and not is_ai;
  if human_count <> selected_room.human_player_limit then
    raise exception using errcode = 'P0001', message = 'animal_players_incomplete';
  end if;
  for seat in 1..4 loop
    if not exists (select 1 from public.animal_equation_players where room_id = p_room_id and seat_number = seat) then
      insert into public.animal_equation_players(room_id, profile_id, display_name, seat_number, is_ai, ai_accuracy)
      values (p_room_id, null, ai_names[ai_index], seat, true, round((0.6 + random() * 0.2)::numeric, 3));
      ai_index := ai_index + 1;
    end if;
  end loop;
  with shuffled as (
    select id, row_number() over (order by random())::integer as new_order
    from public.animal_equation_cards where room_id = p_room_id
  )
  update public.animal_equation_cards c set deck_order = shuffled.new_order
  from shuffled where c.id = shuffled.id;
  for player_row in select id from public.animal_equation_players where room_id = p_room_id order by seat_number loop
    update public.animal_equation_cards set location = 'hand', owner_player_id = player_row.id
    where id in (
      select id from public.animal_equation_cards where room_id = p_room_id and location = 'deck'
      order by deck_order limit 6
    );
  end loop;
  select id into first_player_id from public.animal_equation_players where room_id = p_room_id order by random() limit 1;
  update public.animal_equation_rooms set
    status = 'playing', current_player_id = first_player_id, turn_number = 1,
    turn_deadline = now() + interval '90 seconds', started_at = now(),
    version = version + 1, updated_at = now()
  where id = p_room_id;
  return public.animal_equation_snapshot(p_room_id);
end;
$$;

create or replace function public.animal_equation_ai_should_defend(
  p_room_id uuid, p_target_player_id uuid, p_actor_player_id uuid,
  p_target_animal_id uuid, p_defense_code text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  defense_id uuid;
  animal_score integer;
  actor_score integer;
  actor_count integer;
  configured_target integer;
  probability numeric;
begin
  select score into animal_score from public.animal_equation_animals where id = p_target_animal_id;
  select p.animal_score, p.animal_count into actor_score, actor_count
  from public.animal_equation_players p where p.id = p_actor_player_id;
  select target_score into configured_target from public.animal_equation_rooms where id = p_room_id;
  select id into defense_id from public.animal_equation_cards
  where room_id = p_room_id and owner_player_id = p_target_player_id and location = 'hand'
    and card_type = 'function' and function_code = p_defense_code order by random() limit 1;
  if defense_id is null then return null; end if;
  probability := case animal_score when 20 then 1.0 when 15 then 0.8 when 10 then 0.6 else 0.4 end;
  if p_defense_code = 'gender_error' and (actor_score + animal_score >= configured_target or actor_count + 1 >= 4) then
    probability := 1.0;
  end if;
  return case when random() < probability then defense_id else null end;
end;
$$;

-- 先宣告，稍後再補上完整 AI 反應內容，供 AI 回合函式安全呼叫。
create or replace function public.animal_equation_respond_ai_if_needed(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$ begin return; end; $$;

create or replace function public.animal_equation_run_ai_turn(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  ai_player public.animal_equation_players%rowtype;
  function_card public.animal_equation_cards%rowtype;
  target_animal public.animal_equation_animals%rowtype;
  defense_card_id uuid;
  new_action_id uuid;
  radical_ids uuid[];
  variable_values jsonb := '{}'::jsonb;
  desired_valid boolean;
  round_index integer;
begin
  if not public.animal_equation_is_participant(p_room_id) then
    raise exception using errcode = '42501', message = 'animal_room_access_denied';
  end if;
  select * into selected_room from public.animal_equation_rooms where id = p_room_id for update;
  if selected_room.status = 'reaction' then
    perform public.animal_equation_respond_ai_if_needed(p_room_id);
    return public.animal_equation_snapshot(p_room_id);
  end if;
  select * into ai_player from public.animal_equation_players where id = selected_room.current_player_id;
  if selected_room.status <> 'playing' or ai_player.id is null or not ai_player.is_ai then
    return public.animal_equation_snapshot(p_room_id);
  end if;
  round_index := floor((selected_room.turn_number - 1) / 4.0)::integer;

  if random() < 0.35 then
    select * into function_card from public.animal_equation_cards
    where room_id = p_room_id and owner_player_id = ai_player.id and location = 'hand'
      and card_type = 'function' and function_code in ('tame','accuse','tempt')
    order by random() limit 1;
  end if;
  if function_card.id is not null then
    if function_card.function_code = 'tame' then
      select * into target_animal from public.animal_equation_animals
      where room_id = p_room_id and not revealed and owner_player_id is null order by random() limit 1;
    else
      select a.* into target_animal from public.animal_equation_animals a
      join public.animal_equation_players owner on owner.id = a.owner_player_id
      where a.room_id = p_room_id and a.revealed and a.owner_player_id <> ai_player.id
        and (owner.is_ai or selected_room.ai_human_attack_round <> round_index)
      order by random() limit 1;
    end if;
  end if;

  if function_card.id is not null and target_animal.id is not null then
    update public.animal_equation_players set last_play=jsonb_build_object(
      'kind','function','mode',function_card.function_code,
      'cards',jsonb_build_array(jsonb_build_object(
        'id',function_card.id,'code',function_card.card_code,'label',function_card.label)),
      'animalId',target_animal.id,'turnNumber',selected_room.turn_number
    ) where id=ai_player.id;
    if function_card.function_code = 'tame' then
      update public.animal_equation_animals set owner_player_id = ai_player.id, revealed = true where id = target_animal.id;
      update public.animal_equation_cards set location = 'discard', owner_player_id = null where id = function_card.id;
      insert into public.animal_equation_function_actions(room_id,actor_player_id,function_card_id,function_code,target_animal_id,result_code,resolved_at)
      values (p_room_id,ai_player.id,function_card.id,'tame',target_animal.id,'tame_success',now()) returning id into new_action_id;
      perform public.animal_equation_refill_hand(p_room_id, ai_player.id);
      perform public.animal_equation_finish_function_turn(p_room_id,ai_player.id,new_action_id,'tame_success',null);
      return public.animal_equation_snapshot(p_room_id);
    end if;
    insert into public.animal_equation_function_actions(
      room_id,actor_player_id,function_card_id,function_code,target_animal_id,target_player_id,response_deadline
    ) values (
      p_room_id,ai_player.id,function_card.id,function_card.function_code,target_animal.id,target_animal.owner_player_id,now()+interval '8 seconds'
    ) returning id into new_action_id;
    update public.animal_equation_rooms set
      status='reaction', pending_function_action_id=new_action_id,
      ai_human_attack_round=case when exists (
        select 1 from public.animal_equation_players where id=target_animal.owner_player_id and not is_ai
      ) then round_index else ai_human_attack_round end,
      version=version+1, updated_at=now()
    where id=p_room_id;
    if exists (select 1 from public.animal_equation_players where id=target_animal.owner_player_id and is_ai) then
      defense_card_id := public.animal_equation_ai_should_defend(
        p_room_id,target_animal.owner_player_id,ai_player.id,target_animal.id,
        case function_card.function_code when 'accuse' then 'clarify' else 'gender_error' end
      );
      perform public.animal_equation_resolve_function_action(p_room_id,defense_card_id);
    end if;
    return public.animal_equation_snapshot(p_room_id);
  end if;

  desired_valid := random() < ai_player.ai_accuracy;
  if desired_valid then
    select array[c.id,d.id] into radical_ids
    from public.animal_equation_cards c
      join public.animal_equation_cards d on d.room_id=c.room_id and d.owner_player_id=c.owner_player_id
        and d.location='hand' and d.card_type='radical' and d.id>c.id
        and (case when c.variable_code='n' then coalesce(c.radicand,1)::integer else public.animal_equation_squarefree_part(c.radicand::integer) end)
          = (case when d.variable_code='n' then coalesce(d.radicand,1)::integer else public.animal_equation_squarefree_part(d.radicand::integer) end)
      where c.room_id=p_room_id and c.owner_player_id=ai_player.id and c.location='hand' and c.card_type='radical'
      order by random() limit 1;
  else
    select array[c.id,d.id] into radical_ids
    from public.animal_equation_cards c
      join public.animal_equation_cards d on d.room_id=c.room_id and d.owner_player_id=c.owner_player_id
        and d.location='hand' and d.card_type='radical' and d.id>c.id
        and (case when c.variable_code='n' then coalesce(c.radicand,1)::integer else public.animal_equation_squarefree_part(c.radicand::integer) end)
          <> (case when d.variable_code='n' then coalesce(d.radicand,1)::integer else public.animal_equation_squarefree_part(d.radicand::integer) end)
      where c.room_id=p_room_id and c.owner_player_id=ai_player.id and c.location='hand' and c.card_type='radical'
      order by random() limit 1;
  end if;
  if coalesce(cardinality(radical_ids),0) < 2 then
    select array[id] into radical_ids from public.animal_equation_cards
    where room_id=p_room_id and owner_player_id=ai_player.id and location='hand' and card_type='radical'
    order by random() limit 1;
    desired_valid := true;
  end if;
  if radical_ids is null then
    update public.animal_equation_rooms set turn_deadline=now()-interval '1 second' where id=p_room_id;
    return public.animal_equation_advance(p_room_id);
  end if;
  select coalesce(jsonb_object_agg(id::text,(floor(random()*5)+1)::integer),'{}'::jsonb)
  into variable_values from public.animal_equation_cards where id=any(radical_ids) and variable_code='n';
  insert into public.animal_equation_plays(
    room_id,player_id,turn_number,play_mode,selected_card_ids,variable_values,is_valid,review_deadline
  ) values (
    p_room_id,ai_player.id,selected_room.turn_number,
    case when cardinality(radical_ids)=1 then 'single' else 'same_family' end,
    radical_ids,variable_values,desired_valid,
    case when cardinality(radical_ids)=1 then now() else now()+interval '8 seconds' end
  ) returning id into new_action_id;
  update public.animal_equation_players set last_play=jsonb_build_object(
    'kind','radical',
    'mode',case when cardinality(radical_ids)=1 then 'single' else 'same_family' end,
    'cards',coalesce((select jsonb_agg(jsonb_build_object(
      'id',c.id,'code',c.card_code,'label',c.label,
      'variableValue',variable_values ->> c.id::text
    ) order by array_position(radical_ids,c.id))
    from public.animal_equation_cards c where c.id=any(radical_ids)),'[]'::jsonb),
    'turnNumber',selected_room.turn_number
  ) where id=ai_player.id;
  update public.animal_equation_rooms set status='review',pending_play_id=new_action_id,version=version+1,updated_at=now()
  where id=p_room_id;
  if cardinality(radical_ids)=1 then perform public.animal_equation_resolve_pending(p_room_id,null); end if;
  return public.animal_equation_snapshot(p_room_id);
end;
$$;

create or replace function public.animal_equation_advance_with_ai(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  selected_play public.animal_equation_plays%rowtype;
  ai_challenger uuid;
  challenger_accuracy numeric;
begin
  if not public.animal_equation_is_participant(p_room_id) then
    raise exception using errcode = '42501', message = 'animal_room_access_denied';
  end if;
  select * into selected_room from public.animal_equation_rooms where id=p_room_id for update;
  if selected_room.status='review' then
    select * into selected_play from public.animal_equation_plays where id=selected_room.pending_play_id;
    if selected_play.review_deadline<=now() and not selected_play.is_valid
      and exists (select 1 from public.animal_equation_players where id=selected_play.player_id and not is_ai) then
      select id, ai_accuracy into ai_challenger, challenger_accuracy from public.animal_equation_players
      where room_id=p_room_id and is_ai order by random() limit 1;
      if ai_challenger is not null and random()<challenger_accuracy then
        perform public.animal_equation_resolve_pending(p_room_id,ai_challenger);
        return public.animal_equation_snapshot(p_room_id);
      end if;
    end if;
  end if;
  perform public.animal_equation_advance(p_room_id);
  return public.animal_equation_snapshot(p_room_id);
end;
$$;

create or replace function public.animal_equation_count_valid_play()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.resolved_at is null and new.resolved_at is not null and new.is_valid then
    update public.animal_equation_players set valid_radical_plays=valid_radical_plays+1
    where id=new.player_id and not is_ai;
  end if;
  return new;
end;
$$;
drop trigger if exists animal_equation_count_valid_play_trigger on public.animal_equation_plays;
create trigger animal_equation_count_valid_play_trigger
after update of resolved_at on public.animal_equation_plays
for each row execute function public.animal_equation_count_valid_play();

-- AI 玩家被指控或誘惑時，依動物分值與勝負風險決定是否防禦。
create or replace function public.animal_equation_respond_ai_if_needed(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  action public.animal_equation_function_actions%rowtype;
  defense_id uuid;
begin
  select * into selected_room from public.animal_equation_rooms where id=p_room_id for update;
  if selected_room.status<>'reaction' then return; end if;
  select * into action from public.animal_equation_function_actions where id=selected_room.pending_function_action_id;
  if not exists (select 1 from public.animal_equation_players where id=action.target_player_id and is_ai) then return; end if;
  defense_id := public.animal_equation_ai_should_defend(
    p_room_id,action.target_player_id,action.actor_player_id,action.target_animal_id,
    case action.function_code when 'accuse' then 'clarify' else 'gender_error' end
  );
  perform public.animal_equation_resolve_function_action(p_room_id,defense_id);
end;
$$;

-- 把 AI 欄位加進既有快照，不公開其他玩家手牌。
create or replace function public.animal_equation_snapshot_with_ai(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  base jsonb;
  players_json jsonb;
  selected_room public.animal_equation_rooms%rowtype;
begin
  base := public.animal_equation_snapshot(p_room_id);
  select * into selected_room from public.animal_equation_rooms where id=p_room_id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',p.id,'displayName',p.display_name,'seatNumber',p.seat_number,
    'animalScore',p.animal_score,'animalCount',p.animal_count,
    'judgementStars',p.judgement_stars,'isAi',p.is_ai,
    'winCount',p.win_count,'leftAt',p.left_at,'lastPlay',p.last_play,
    'validRadicalPlays',p.valid_radical_plays,
    'connected',case when p.is_ai then true else p.left_at is null and p.last_seen_at>=now()-interval '30 seconds' end
  ) order by p.seat_number),'[]'::jsonb) into players_json
  from public.animal_equation_players p where p.room_id=p_room_id;
  return base || jsonb_build_object(
    'players',players_json,'humanPlayerLimit',selected_room.human_player_limit,
    'targetScore',selected_room.target_score,'gameMode',selected_room.game_mode,
    'gameNumber',selected_room.game_number,'firstPlayerRolls',selected_room.first_player_rolls,
    'deckCount',(select count(*) from public.animal_equation_cards where room_id=p_room_id and location='deck'),
    'discardCount',(select count(*) from public.animal_equation_cards where room_id=p_room_id and location='discard'),
    'currentPlayerIsAi',coalesce((select is_ai from public.animal_equation_players where id=selected_room.current_player_id),false)
  );
end;
$$;

insert into public.learning_activities(
  learning_system_id,activity_code,activity_name,launch_path,
  question_count_a,question_count_b,target_score,display_order,is_active
)
select id,'animal_equation_solo','根式馬戲團單人對戰','&game=animal-equation&solo=1',1,1,100,20,true
from public.learning_systems where lower(subject_code::text)='math'
on conflict (learning_system_id,activity_code) do update set
  activity_name=excluded.activity_name,launch_path=excluded.launch_path,target_score=excluded.target_score,
  is_active=excluded.is_active,updated_at=now();

grant execute on function public.animal_equation_create_with_mode(text,integer) to authenticated;
grant execute on function public.animal_equation_run_ai_turn(uuid) to authenticated;
grant execute on function public.animal_equation_snapshot_with_ai(uuid) to authenticated;
grant execute on function public.animal_equation_advance_with_ai(uuid) to authenticated;
revoke all on function public.animal_equation_ai_should_defend(uuid,uuid,uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.animal_equation_respond_ai_if_needed(uuid) from public,anon,authenticated;
