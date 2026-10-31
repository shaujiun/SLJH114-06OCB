-- 已發布的 20260827 房間、根式與功能牌 migration 不可改寫；
-- 本升級在既有資料表上加入同房多局設定及精確根式判定。
alter table public.animal_equation_rooms
  add column if not exists game_mode text not null default 'basic'
    check (game_mode in ('basic','advanced')),
  add column if not exists target_score smallint not null default 60
    check (target_score in (40,45,50,55,60)),
  add column if not exists game_number integer not null default 0,
  add column if not exists first_player_rolls jsonb not null default '[]'::jsonb;
alter table public.animal_equation_players
  add column if not exists win_count integer not null default 0 check (win_count >= 0),
  add column if not exists left_at timestamptz,
  add column if not exists last_play jsonb;

-- 正式庫目前沒有遊戲房間；保留 finished 房的房碼供同房續局使用。
drop index if exists public.animal_equation_active_room_code_unique;
create unique index animal_equation_active_room_code_unique
  on public.animal_equation_rooms(room_code) where status <> 'closed';

-- 先抽完原牌庫；牌庫空時才洗棄牌，避免提前回收本回合的牌。
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
  drawn_count integer;
  next_order integer;
begin
  select count(*) into hand_count from public.animal_equation_cards
  where room_id = p_room_id and owner_player_id = p_player_id and location = 'hand';
  need_count := greatest(0, 6 - hand_count);
  while need_count > 0 loop
    select count(*) into deck_count from public.animal_equation_cards
    where room_id = p_room_id and location = 'deck';
    if deck_count = 0 then
      select coalesce(max(deck_order), 0) into next_order
      from public.animal_equation_cards where room_id = p_room_id;
      with shuffled as (
        select id, next_order + row_number() over (order by random())::integer as new_order
        from public.animal_equation_cards
        where room_id = p_room_id and location = 'discard'
      )
      update public.animal_equation_cards c set
        location = 'deck', owner_player_id = null, deck_order = shuffled.new_order
      from shuffled where c.id = shuffled.id;
      get diagnostics drawn_count = row_count;
      if drawn_count = 0 then exit; end if;
    end if;
    with drawn as (
      select id from public.animal_equation_cards
      where room_id = p_room_id and location = 'deck'
      order by deck_order, created_at limit need_count
    )
    update public.animal_equation_cards c set location = 'hand', owner_player_id = p_player_id
    from drawn where c.id = drawn.id;
    get diagnostics drawn_count = row_count;
    if drawn_count = 0 then exit; end if;
    need_count := need_count - drawn_count;
  end loop;
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
      where room_code = new_code and status <> 'closed'
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

create or replace function public.animal_equation_vector_multiply(a numeric[],b numeric[])
returns numeric[] language sql immutable set search_path=public as $$
  select array[
    a[1]*b[1]+2*a[2]*b[2]+3*a[3]*b[3]+6*a[4]*b[4],
    a[1]*b[2]+a[2]*b[1]+3*a[3]*b[4]+3*a[4]*b[3],
    a[1]*b[3]+a[3]*b[1]+2*a[2]*b[4]+2*a[4]*b[2],
    a[1]*b[4]+a[4]*b[1]+a[2]*b[3]+a[3]*b[2]
  ]::numeric[];
$$;

create or replace function public.animal_equation_vector_add(a numeric[],b numeric[])
returns numeric[] language sql immutable set search_path=public as $$
  select array[a[1]+b[1],a[2]+b[2],a[3]+b[3],a[4]+b[4]]::numeric[];
$$;
create or replace function public.animal_equation_vector_subtract(a numeric[],b numeric[])
returns numeric[] language sql immutable set search_path=public as $$
  select array[a[1]-b[1],a[2]-b[2],a[3]-b[3],a[4]-b[4]]::numeric[];
$$;

create or replace function public.animal_equation_evaluate_exact(
  p_node jsonb,p_room_id uuid,p_player_id uuid,p_variable_values jsonb
)
returns numeric[]
language plpgsql security definer set search_path=public as $$
declare
  selected_card public.animal_equation_cards%rowtype;
  selected_id uuid;
  coefficient_value numeric;
  variable_text text;
  outside_value integer := 1;
  squarefree integer;
  factor integer := 2;
  numerator numeric[] := array[0,0,0,0]::numeric[];
  denominator numeric[] := array[1,0,0,0]::numeric[];
  left_value numeric[];
  right_value numeric[];
  ln numeric[]; ld numeric[]; rn numeric[]; rd numeric[];
  result_num numeric[]; result_den numeric[];
  operator_code text;
begin
  if p_node is null then raise exception using errcode='P0001',message='animal_expression_incomplete'; end if;
  if p_node ->> 'type'='card' then
    begin selected_id := (p_node ->> 'cardId')::uuid;
    exception when others then raise exception using errcode='P0001',message='animal_expression_incomplete'; end;
    select * into selected_card from public.animal_equation_cards
    where id=selected_id and room_id=p_room_id and owner_player_id=p_player_id
      and location='hand' and card_type='radical';
    if selected_card.id is null then raise exception using errcode='P0001',message='animal_card_not_in_hand'; end if;
    if selected_card.variable_code='n' then
      variable_text := p_variable_values ->> selected_id::text;
      if variable_text is null or variable_text !~ '^[1-9]$' then
        raise exception using errcode='P0001',message='animal_variable_positive_integer_required';
      end if;
      coefficient_value := variable_text::numeric;
    else coefficient_value := selected_card.coefficient;
    end if;
    squarefree := coalesce(selected_card.radicand::integer,1);
    while factor*factor <= squarefree loop
      while mod(squarefree,factor*factor)=0 loop
        outside_value := outside_value*factor;
        squarefree := squarefree/(factor*factor);
      end loop;
      factor := factor+1;
    end loop;
    if squarefree not in (1,2,3,6) then
      raise exception using errcode='P0001',message='animal_expression_operator_invalid';
    end if;
    numerator[case squarefree when 1 then 1 when 2 then 2 when 3 then 3 else 4 end]
      := coefficient_value*outside_value;
    return numerator||denominator;
  end if;
  operator_code := p_node ->> 'operator';
  if p_node ->> 'type'<>'operation' or operator_code not in ('+','-','*','/') then
    raise exception using errcode='P0001',message='animal_expression_operator_invalid';
  end if;
  left_value := public.animal_equation_evaluate_exact(p_node->'left',p_room_id,p_player_id,p_variable_values);
  right_value := public.animal_equation_evaluate_exact(p_node->'right',p_room_id,p_player_id,p_variable_values);
  ln := left_value[1:4]; ld := left_value[5:8];
  rn := right_value[1:4]; rd := right_value[5:8];
  if operator_code='+' then
    result_num := public.animal_equation_vector_add(
      public.animal_equation_vector_multiply(ln,rd),
      public.animal_equation_vector_multiply(rn,ld));
    result_den := public.animal_equation_vector_multiply(ld,rd);
  elsif operator_code='-' then
    result_num := public.animal_equation_vector_subtract(
      public.animal_equation_vector_multiply(ln,rd),
      public.animal_equation_vector_multiply(rn,ld));
    result_den := public.animal_equation_vector_multiply(ld,rd);
  elsif operator_code='*' then
    result_num := public.animal_equation_vector_multiply(ln,rn);
    result_den := public.animal_equation_vector_multiply(ld,rd);
  else
    if rn=array[0,0,0,0]::numeric[] then
      raise exception using errcode='P0001',message='animal_expression_division_by_zero';
    end if;
    result_num := public.animal_equation_vector_multiply(ln,rd);
    result_den := public.animal_equation_vector_multiply(ld,rn);
  end if;
  return result_num||result_den;
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

  if selected_play.is_valid or p_challenger_player_id is null then
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
  left_value numeric[];
  right_value numeric[];
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
  if selected_room.game_mode = 'basic' and p_play_mode = 'equation' then
    raise exception using errcode='P0001', message='animal_advanced_mode_required';
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
  where p_play_mode = 'equation' and c.id = any(p_selected_card_ids) and c.variable_code = 'n'
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
    if selected_count not between 3 and 6 then
      raise exception using errcode='P0001', message='animal_equation_requires_three_to_six';
    end if;
    used_ids := public.animal_equation_collect_expression_cards(p_left_expression)
      || public.animal_equation_collect_expression_cards(p_right_expression);
    select array_agg(id::text order by id::text) into normalized_selected from unnest(p_selected_card_ids) id;
    select array_agg(id::text order by id::text) into normalized_used from unnest(used_ids) id;
    if cardinality(used_ids) <> selected_count
      or (select count(distinct id) from unnest(used_ids) id) <> selected_count
      or normalized_used is distinct from normalized_selected then
      raise exception using errcode = 'P0001', message = 'animal_selected_cards_once';
    end if;
    left_value := public.animal_equation_evaluate_exact(p_left_expression,p_room_id,me_player.id,coalesce(p_variable_values,'{}'::jsonb));
    right_value := public.animal_equation_evaluate_exact(p_right_expression,p_room_id,me_player.id,coalesce(p_variable_values,'{}'::jsonb));
    play_valid := public.animal_equation_vector_multiply(left_value[1:4],right_value[5:8])
      = public.animal_equation_vector_multiply(right_value[1:4],left_value[5:8]);
  end if;

  insert into public.animal_equation_plays(
    room_id, player_id, turn_number, play_mode, selected_card_ids,
    left_expression, right_expression, variable_values, is_valid, review_deadline
  ) values (
    p_room_id, me_player.id, selected_room.turn_number, p_play_mode, p_selected_card_ids,
    p_left_expression, p_right_expression, coalesce(p_variable_values, '{}'::jsonb), play_valid,
    case when p_play_mode = 'single' then now() else review_until end
  ) returning id into new_play_id;

  update public.animal_equation_players set last_play=jsonb_build_object(
    'kind','radical','mode',p_play_mode,
    'cards',coalesce((select jsonb_agg(jsonb_build_object(
      'id',c.id,'code',c.card_code,'label',c.label,
      'variableValue',p_variable_values ->> c.id::text
    ) order by array_position(p_selected_card_ids,c.id))
    from public.animal_equation_cards c where c.id=any(p_selected_card_ids)),'[]'::jsonb),
    'left',p_left_expression,'right',p_right_expression,
    'turnNumber',selected_room.turn_number
  ) where id=me_player.id;

  update public.animal_equation_rooms set
    status = 'review', pending_play_id = new_play_id,
    version = version + 1, updated_at = now()
  where id = p_room_id;
  if p_play_mode = 'single' then perform public.animal_equation_resolve_pending(p_room_id, null); end if;
  return public.animal_equation_snapshot(p_room_id);
end;
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
  where p.room_id = p_room_id and (p.animal_count >= 4 or p.animal_score >= selected_room.target_score)
  order by case when p.id = p_actor_player_id then 0 else 1 end,
    p.animal_count desc, p.animal_score desc, p.judgement_stars desc, p.seat_number
  limit 1;

  if winner_id is not null then
    update public.animal_equation_players set win_count=win_count+1 where id=winner_id;
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
    update public.animal_equation_players set last_play=jsonb_build_object(
      'kind','function','cards',jsonb_build_array(jsonb_build_object(
        'id',defense_card.id,'code',defense_card.card_code,'label',defense_card.label)),
      'turnNumber',selected_room.turn_number,'defense',true
    ) where id=selected_action.target_player_id;
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
    update public.animal_equation_players set last_play=jsonb_build_object(
      'kind','function','cards',jsonb_build_array(jsonb_build_object(
        'id',selected_card.id,'code',selected_card.card_code,'label',selected_card.label)),
      'targetAnimalId',selected_animal.id,'turnNumber',selected_room.turn_number
    ) where id=me_player.id;
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
  update public.animal_equation_players set last_play=jsonb_build_object(
    'kind','function','cards',jsonb_build_array(jsonb_build_object(
      'id',selected_card.id,'code',selected_card.card_code,'label',selected_card.label)),
    'targetAnimalId',selected_animal.id,'turnNumber',selected_room.turn_number
  ) where id=me_player.id;
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

revoke all on function public.animal_equation_vector_multiply(numeric[],numeric[]) from public,anon,authenticated;
revoke all on function public.animal_equation_vector_add(numeric[],numeric[]) from public,anon,authenticated;
revoke all on function public.animal_equation_vector_subtract(numeric[],numeric[]) from public,anon,authenticated;
revoke all on function public.animal_equation_evaluate_exact(jsonb,uuid,uuid,jsonb) from public,anon,authenticated;
