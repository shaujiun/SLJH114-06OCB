-- Apply a challenge to the opponent's next question, and award its bonus only
-- after that raised question is completed on the first try.
create or replace function public.factor_clash_report_question(
  p_room_code text,p_seat_token text,p_question_number integer,p_points integer,p_first_try boolean,
  p_elapsed_ms integer,p_timed_out boolean,p_time_limit_ms integer)
returns boolean language plpgsql security definer set search_path = public
as $$
declare selected_room public.factor_clash_rooms%rowtype; me public.factor_clash_room_players%rowtype;
  opponent public.factor_clash_room_players%rowtype; next_strong smallint; next_weak smallint; adapted_tier smallint;
  next_current_tier smallint; next_energy smallint; energy_gain integer := 0; next_hint_tokens smallint;
  new_score integer; fast_success boolean; weak_result boolean;
begin
  select * into selected_room from public.factor_clash_rooms where room_code=p_room_code for update;
  if not found then raise exception 'factor_room_not_found'; end if;
  select * into me from public.factor_clash_room_players where room_id=selected_room.id and token_hash=public.factor_clash_token_hash(p_seat_token) for update;
  if me.id is null then raise exception 'factor_seat_invalid'; end if;
  if selected_room.status<>'playing' or p_question_number<>me.progress+1 then raise exception 'factor_submission_order_invalid'; end if;
  if p_points not in (0,1,3) or p_elapsed_ms<0 or p_time_limit_ms not between 60000 and 300000 then raise exception 'factor_submission_invalid'; end if;
  select * into opponent from public.factor_clash_room_players where room_id=selected_room.id and id<>me.id and status<>'left' order by seat_no limit 1;

  fast_success := p_first_try and p_points=3 and not p_timed_out and p_elapsed_ms<=p_time_limit_ms/2;
  weak_result := p_points=0 or p_points=1 or p_timed_out or (p_points=3 and p_elapsed_ms>=p_time_limit_ms*4/5);
  next_strong := case when fast_success then least(2,me.strong_streak+1) else 0 end;
  next_weak := case when weak_result then least(2,me.weak_streak+1) else 0 end;
  adapted_tier := me.challenge_tier;
  if next_strong>=2 then adapted_tier:=least(5,adapted_tier+1); next_strong:=0; end if;
  if next_weak>=2 then adapted_tier:=greatest(1,adapted_tier-1); next_weak:=0; end if;
  next_current_tier := greatest(1,least(5,adapted_tier+me.pending_tier_boost));

  new_score := me.score+p_points;
  if p_points>0 then energy_gain:=1; end if;
  if p_points>0 and opponent.id is not null and new_score<=opponent.score-4 then energy_gain:=energy_gain+1; end if;
  if me.challenge_bonus_pending and p_first_try and p_points=3 then energy_gain:=energy_gain+1; end if;
  next_energy := least(3,me.skill_energy+energy_gain);
  next_hint_tokens := me.hint_tokens;
  if opponent.id is not null and new_score<=opponent.score-7 and not me.comeback_hint_used then
    next_hint_tokens:=least(2,next_hint_tokens+1);
  end if;

  update public.factor_clash_room_players set progress=p_question_number,score=new_score,
    first_try_correct=first_try_correct+case when p_first_try and p_points=3 then 1 else 0 end,
    total_elapsed_ms=total_elapsed_ms+p_elapsed_ms,timeout_count=timeout_count+case when p_timed_out then 1 else 0 end,
    status=case when p_question_number=10 then 'finished' else status end,last_seen_at=now(),
    challenge_tier=adapted_tier,current_tier=next_current_tier,strong_streak=next_strong,weak_streak=next_weak,
    skill_energy=next_energy,hint_tokens=next_hint_tokens,pending_tier_boost=0,
    challenge_bonus_pending=me.pending_tier_boost>0,
    comeback_hint_used=case when opponent.id is not null and new_score<=opponent.score-7 then true else comeback_hint_used end
    where id=me.id;
  if not exists(select 1 from public.factor_clash_room_players where room_id=selected_room.id and status='connected') then
    update public.factor_clash_rooms set status='finished',finished_at=now(),version=version+1,updated_at=now() where id=selected_room.id;
  else update public.factor_clash_rooms set version=version+1,updated_at=now() where id=selected_room.id; end if;
  return true;
end $$;
create or replace function public.factor_clash_use_skill(p_room_code text,p_seat_token text,p_skill text,p_question_number integer)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare selected_room public.factor_clash_rooms%rowtype; me public.factor_clash_room_players%rowtype;
  opponent public.factor_clash_room_players%rowtype; skill_cost smallint := 1; blocked boolean := false;
  next_energy smallint; next_tokens smallint; next_shield smallint;
begin
  select * into selected_room from public.factor_clash_rooms where room_code=p_room_code for update;
  if not found then raise exception 'factor_room_not_found'; end if;
  select * into me from public.factor_clash_room_players where room_id=selected_room.id and token_hash=public.factor_clash_token_hash(p_seat_token) for update;
  if me.id is null then raise exception 'factor_seat_invalid'; end if;
  if selected_room.status<>'playing' or p_question_number<>me.progress+1 then raise exception 'factor_submission_order_invalid'; end if;
  if p_skill not in ('hint','extra_time','retry','shield','challenge') then raise exception 'factor_skill_invalid'; end if;
  if me.last_skill_question=p_question_number then raise exception 'factor_skill_already_used'; end if;
  if p_skill='challenge' then skill_cost:=2; end if;
  next_tokens:=me.hint_tokens; next_shield:=me.shield_count;
  if p_skill='hint' and next_tokens>0 then next_tokens:=next_tokens-1; skill_cost:=0; end if;
  if me.skill_energy<skill_cost then raise exception 'factor_skill_energy_insufficient'; end if;
  if p_skill='shield' and me.shield_count>0 then raise exception 'factor_skill_invalid'; end if;
  next_energy:=me.skill_energy-skill_cost;

  if p_skill='shield' then next_shield:=1; end if;
  if p_skill='challenge' then
    select * into opponent from public.factor_clash_room_players where room_id=selected_room.id and id<>me.id and status='connected' order by seat_no limit 1 for update;
    if opponent.id is null or opponent.progress>=9 then raise exception 'factor_opponent_unavailable'; end if;
    if opponent.shield_count>0 then
      update public.factor_clash_room_players set shield_count=0 where id=opponent.id;
      blocked:=true;
    else
      update public.factor_clash_room_players set pending_tier_boost=1 where id=opponent.id;
    end if;
  end if;

  update public.factor_clash_room_players set skill_energy=next_energy,hint_tokens=next_tokens,
    shield_count=next_shield,last_skill_question=p_question_number,last_seen_at=now() where id=me.id;
  update public.factor_clash_rooms set version=version+1,updated_at=now() where id=selected_room.id;
  return jsonb_build_object('skill',p_skill,'blocked',blocked,'skillEnergy',next_energy,'hintTokens',next_tokens,'shieldCount',next_shield);
end $$;

