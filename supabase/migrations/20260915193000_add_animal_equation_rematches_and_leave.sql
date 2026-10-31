-- 同房多局與離房：勝場只在這間房間存在，不寫入跨房排行榜。
create or replace function public.animal_equation_start_game(
  p_room_id uuid, p_game_mode text, p_target_score integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  human_count integer;
  player_row record;
  seat smallint;
  ai_index integer := 1;
  ai_names text[] := array['AI 小狐','AI 海豚','AI 樹懶'];
  candidate_ids uuid[];
  round_scores jsonb;
  rolls jsonb := '[]'::jsonb;
  roll_round integer := 0;
  die_one integer;
  die_two integer;
  total integer;
  highest integer;
  first_player_id uuid;
begin
  select * into selected_room from public.animal_equation_rooms where id=p_room_id for update;
  if selected_room.id is null or selected_room.host_profile_id <> auth.uid() then
    raise exception using errcode='42501', message='animal_host_required';
  end if;
  if selected_room.status not in ('lobby','finished') then
    raise exception using errcode='P0001', message='animal_room_started';
  end if;
  if p_game_mode not in ('basic','advanced') or p_target_score not in (40,45,50,55,60) then
    raise exception using errcode='P0001', message='animal_game_settings_invalid';
  end if;
  select count(*) into human_count from public.animal_equation_players
  where room_id=p_room_id and not is_ai and left_at is null
    and last_seen_at >= now()-interval '45 seconds';
  if human_count <> selected_room.human_player_limit then
    raise exception using errcode='P0001', message='animal_players_incomplete';
  end if;

  if selected_room.game_number > 0 then
    -- 先清掉上一局紀錄，再重設牌與動物；勝場留在玩家列。
    update public.animal_equation_rooms set pending_play_id=null,pending_function_action_id=null
    where id=p_room_id;
    delete from public.animal_equation_function_actions where room_id=p_room_id;
    delete from public.animal_equation_plays where room_id=p_room_id;
    update public.animal_equation_cards set location='deck',owner_player_id=null where room_id=p_room_id;
    delete from public.animal_equation_animals where room_id=p_room_id;
    insert into public.animal_equation_animals(room_id,position,animal_code,animal_name,score)
    select p_room_id,row_number() over (order by random())::smallint,
      seed.code,seed.name,seed.score
    from (values
      ('deer','梅花鹿',20),('octopus','章魚',20),('sloth','樹懶',20),('beluga','白鯨',20),
      ('ostrich','鴕鳥',15),('poodle','紅貴賓',15),('tabby','虎斑貓',15),('dolphin','海豚',15),
      ('beaver','海狸',10),('wallaby','矮袋鼠',10),('pig','粉紅豬',10),('goldfish','金魚',10),
      ('chihuahua','吉娃娃',5),('fox','狐狸',5),('maltese','馬爾濟斯',5),('corgi','柯基犬',5)
    ) seed(code,name,score);
    update public.animal_equation_players set
      animal_score=0,animal_count=0,judgement_stars=0,valid_radical_plays=0,last_play=null
    where room_id=p_room_id;
  end if;

  for seat in 1..4 loop
    if not exists (select 1 from public.animal_equation_players
      where room_id=p_room_id and seat_number=seat) then
      insert into public.animal_equation_players(
        room_id,profile_id,display_name,seat_number,is_ai,ai_accuracy
      ) values (p_room_id,null,ai_names[ai_index],seat,true,
        round((0.6+random()*0.2)::numeric,3));
      ai_index := ai_index+1;
    end if;
  end loop;
  with shuffled as (
    select id,row_number() over (order by random())::integer new_order
    from public.animal_equation_cards where room_id=p_room_id
  ) update public.animal_equation_cards c set deck_order=shuffled.new_order
    from shuffled where c.id=shuffled.id;
  for player_row in select id from public.animal_equation_players
    where room_id=p_room_id and left_at is null order by seat_number loop
    update public.animal_equation_cards set location='hand',owner_player_id=player_row.id
    where id in (select id from public.animal_equation_cards
      where room_id=p_room_id and location='deck' order by deck_order limit 6);
  end loop;

  select array_agg(id order by seat_number) into candidate_ids
  from public.animal_equation_players where room_id=p_room_id and left_at is null;
  loop
    roll_round := roll_round+1;
    round_scores := '[]'::jsonb;
    highest := -1;
    for player_row in select id from public.animal_equation_players
      where room_id=p_room_id and id=any(candidate_ids) order by seat_number loop
      die_one := floor(random()*6)::integer+1;
      die_two := floor(random()*6)::integer+1;
      total := die_one+die_two;
      highest := greatest(highest,total);
      round_scores := round_scores || jsonb_build_array(jsonb_build_object(
        'round',roll_round,'playerId',player_row.id,
        'dice',jsonb_build_array(die_one,die_two),'total',total));
    end loop;
    rolls := rolls || round_scores;
    select array_agg((item ->> 'playerId')::uuid) into candidate_ids
    from jsonb_array_elements(round_scores) item where (item ->> 'total')::integer=highest;
    exit when cardinality(candidate_ids)=1;
  end loop;
  first_player_id := candidate_ids[1];
  update public.animal_equation_rooms set
    status='playing',game_mode=p_game_mode,target_score=p_target_score,
    game_number=game_number+1,first_player_rolls=rolls,
    current_player_id=first_player_id,turn_number=1,
    turn_deadline=now()+interval '90 seconds',winner_player_id=null,
    pending_play_id=null,pending_function_action_id=null,last_result=null,
    started_at=now(),finished_at=null,version=version+1,updated_at=now()
  where id=p_room_id;
  return public.animal_equation_snapshot_with_ai(p_room_id);
end;
$$;

create or replace function public.animal_equation_leave(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.animal_equation_rooms%rowtype;
  me_player_id uuid;
  remaining_count integer;
  next_host uuid;
begin
  select * into selected_room from public.animal_equation_rooms where id=p_room_id for update;
  select id into me_player_id from public.animal_equation_players
  where room_id=p_room_id and profile_id=auth.uid() and not is_ai;
  if selected_room.id is null or me_player_id is null or selected_room.status='closed' then
    raise exception using errcode='42501', message='animal_room_access_denied';
  end if;
  update public.animal_equation_players set left_at=now() where id=me_player_id;
  select count(*) into remaining_count from public.animal_equation_players
  where room_id=p_room_id and not is_ai and left_at is null;
  if remaining_count=0 then
    update public.animal_equation_players set win_count=0 where room_id=p_room_id;
    update public.animal_equation_rooms set status='closed',current_player_id=null,
      turn_deadline=null,pending_play_id=null,pending_function_action_id=null,
      version=version+1,updated_at=now() where id=p_room_id;
    return jsonb_build_object('id',p_room_id,'closed',true);
  end if;
  if selected_room.host_profile_id=auth.uid() then
    select profile_id into next_host from public.animal_equation_players
    where room_id=p_room_id and not is_ai and left_at is null
    order by seat_number limit 1;
  end if;
  update public.animal_equation_rooms set
    status=case when status in ('playing','review','reaction') then 'lobby' else status end,
    current_player_id=case when status in ('playing','review','reaction') then null else current_player_id end,
    turn_deadline=case when status in ('playing','review','reaction') then null else turn_deadline end,
    pending_play_id=case when status in ('playing','review','reaction') then null else pending_play_id end,
    pending_function_action_id=case when status in ('playing','review','reaction') then null else pending_function_action_id end,
    host_profile_id=coalesce(next_host,host_profile_id),
    last_result=jsonb_build_object('type','player_left','playerId',me_player_id),
    version=version+1,updated_at=now()
  where id=p_room_id;
  return jsonb_build_object('id',p_room_id,'closed',false);
end;
$$;

revoke all on function public.animal_equation_start_game(uuid,text,integer) from public,anon,authenticated;
revoke all on function public.animal_equation_leave(uuid) from public,anon,authenticated;
revoke all on function public.animal_equation_start(uuid) from authenticated;
grant execute on function public.animal_equation_start_game(uuid,text,integer) to authenticated;
grant execute on function public.animal_equation_leave(uuid) to authenticated;
