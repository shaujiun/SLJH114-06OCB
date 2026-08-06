-- 元素週期表即時對戰：房間、玩家、題目、原子化搶答與伺服器計時。

create table if not exists public.periodic_battle_rooms (
  id uuid primary key default gen_random_uuid(),
  room_code text not null,
  host_profile_id uuid not null references public.contact_book_profiles(id) on delete restrict,
  player_limit smallint not null check (player_limit in (2, 4)),
  level_code text not null check (level_code in ('beginner', 'advanced', 'challenge', 'complete')),
  mode_code text not null check (mode_code in ('name_symbol', 'symbol_name', 'locate', 'mixed')),
  question_count smallint not null check (question_count between 4 and 40),
  status text not null default 'lobby'
    check (status in ('lobby', 'thinking', 'buzzing', 'answering', 'resolved', 'finished', 'closed')),
  current_question integer not null default 0,
  current_attempt smallint not null default 0,
  active_player_id uuid,
  buzzer_player_id uuid,
  attempt_order smallint[] not null default '{}',
  phase_deadline timestamptz,
  ai_action_at timestamptz,
  team_a_score integer not null default 0,
  team_b_score integer not null default 0,
  last_result jsonb,
  version bigint not null default 1,
  started_at timestamptz,
  finished_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint periodic_battle_room_code_format check (room_code ~ '^[0-9]{4}$'),
  constraint periodic_battle_four_player_question_count check (player_limit <> 4 or mod(question_count, 4) = 0)
);

create unique index if not exists periodic_battle_active_code_unique
  on public.periodic_battle_rooms(room_code)
  where status not in ('finished', 'closed');

create table if not exists public.periodic_battle_players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.periodic_battle_rooms(id) on delete cascade,
  profile_id uuid references public.contact_book_profiles(id) on delete set null,
  display_name text not null,
  seat_number smallint not null check (seat_number between 1 and 99),
  team_code text check (team_code in ('A', 'B')),
  is_ai boolean not null default false,
  is_replaced boolean not null default false,
  last_seen_at timestamptz not null default now(),
  joined_at timestamptz not null default now()
);

create unique index if not exists periodic_battle_active_seat_unique
  on public.periodic_battle_players(room_id, seat_number)
  where not is_replaced;

create unique index if not exists periodic_battle_room_profile_unique
  on public.periodic_battle_players(room_id, profile_id)
  where profile_id is not null and not is_replaced;

alter table public.periodic_battle_rooms
  drop constraint if exists periodic_battle_rooms_active_player_id_fkey;
alter table public.periodic_battle_rooms
  add constraint periodic_battle_rooms_active_player_id_fkey
  foreign key (active_player_id) references public.periodic_battle_players(id) on delete set null;

alter table public.periodic_battle_rooms
  drop constraint if exists periodic_battle_rooms_buzzer_player_id_fkey;
alter table public.periodic_battle_rooms
  add constraint periodic_battle_rooms_buzzer_player_id_fkey
  foreign key (buzzer_player_id) references public.periodic_battle_players(id) on delete set null;

create table if not exists public.periodic_battle_questions (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.periodic_battle_rooms(id) on delete cascade,
  position smallint not null,
  mode_code text not null check (mode_code in ('name_symbol', 'symbol_name', 'locate')),
  prompt text not null,
  choices jsonb not null default '[]'::jsonb,
  unique (room_id, position)
);

-- 答案與 AI 正確率不開放直接查詢，僅由 security definer RPC 使用。
create table if not exists public.periodic_battle_answers (
  question_id uuid primary key references public.periodic_battle_questions(id) on delete cascade,
  correct_answer text not null
);

create table if not exists public.periodic_battle_ai_settings (
  player_id uuid primary key references public.periodic_battle_players(id) on delete cascade,
  accuracy smallint not null check (accuracy between 60 and 80)
);

create table if not exists public.periodic_battle_attempts (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.periodic_battle_rooms(id) on delete cascade,
  question_position smallint not null,
  player_id uuid not null references public.periodic_battle_players(id) on delete cascade,
  attempt_number smallint not null,
  submitted_answer text,
  is_correct boolean not null,
  is_timeout boolean not null default false,
  score_delta smallint not null,
  answered_at timestamptz not null default now(),
  unique (room_id, question_position, player_id)
);

alter table public.periodic_battle_rooms enable row level security;
alter table public.periodic_battle_players enable row level security;
alter table public.periodic_battle_questions enable row level security;
alter table public.periodic_battle_answers enable row level security;
alter table public.periodic_battle_ai_settings enable row level security;
alter table public.periodic_battle_attempts enable row level security;

create or replace function public.periodic_battle_is_participant(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.periodic_battle_players player
    where player.room_id = p_room_id
      and player.profile_id = auth.uid()
      and not player.is_replaced
  ) or exists (
    select 1 from public.periodic_battle_rooms room
    where room.id = p_room_id and room.host_profile_id = auth.uid()
  );
$$;

drop policy if exists periodic_battle_rooms_participant_read on public.periodic_battle_rooms;
create policy periodic_battle_rooms_participant_read on public.periodic_battle_rooms
for select to authenticated using (public.periodic_battle_is_participant(id));

drop policy if exists periodic_battle_players_participant_read on public.periodic_battle_players;
create policy periodic_battle_players_participant_read on public.periodic_battle_players
for select to authenticated using (public.periodic_battle_is_participant(room_id));

drop policy if exists periodic_battle_questions_participant_read on public.periodic_battle_questions;
create policy periodic_battle_questions_participant_read on public.periodic_battle_questions
for select to authenticated using (public.periodic_battle_is_participant(room_id));

drop policy if exists periodic_battle_attempts_participant_read on public.periodic_battle_attempts;
create policy periodic_battle_attempts_participant_read on public.periodic_battle_attempts
for select to authenticated using (public.periodic_battle_is_participant(room_id));

create or replace function public.periodic_battle_initial_seats(p_player_limit integer, p_question integer)
returns smallint[]
language sql
immutable
set search_path = public
as $$
  select case
    when p_player_limit = 2 then array[1, 2]::smallint[]
    when mod(p_question - 1, 4) = 0 then array[1, 3]::smallint[]
    when mod(p_question - 1, 4) = 1 then array[2, 4]::smallint[]
    when mod(p_question - 1, 4) = 2 then array[2, 3]::smallint[]
    else array[1, 4]::smallint[]
  end;
$$;

create or replace function public.periodic_battle_snapshot(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.periodic_battle_rooms%rowtype;
  selected_question jsonb;
  players_json jsonb;
  me_id uuid;
  eligible_seats smallint[];
begin
  select * into selected_room from public.periodic_battle_rooms where id = p_room_id;
  if selected_room.id is null or not public.periodic_battle_is_participant(p_room_id) then
    raise exception using errcode = '42501', message = 'battle_room_access_denied';
  end if;

  select player.id into me_id
  from public.periodic_battle_players player
  where player.room_id = p_room_id and player.profile_id = auth.uid() and not player.is_replaced
  limit 1;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', player.id,
    'displayName', player.display_name,
    'seatNumber', player.seat_number,
    'teamCode', player.team_code,
    'isAi', player.is_ai,
    'connected', player.is_ai or player.last_seen_at >= now() - interval '30 seconds',
    'lastSeenAt', player.last_seen_at
  ) order by player.seat_number), '[]'::jsonb)
  into players_json
  from public.periodic_battle_players player
  where player.room_id = p_room_id and not player.is_replaced;

  if selected_room.current_question > 0 then
    select jsonb_build_object(
      'position', question.position,
      'mode', question.mode_code,
      'prompt', question.prompt,
      'choices', question.choices
    ) into selected_question
    from public.periodic_battle_questions question
    where question.room_id = p_room_id and question.position = selected_room.current_question;
  end if;

  eligible_seats := public.periodic_battle_initial_seats(selected_room.player_limit, greatest(selected_room.current_question, 1));

  return jsonb_build_object(
    'id', selected_room.id,
    'code', selected_room.room_code,
    'hostProfileId', selected_room.host_profile_id,
    'isHost', selected_room.host_profile_id = auth.uid(),
    'mePlayerId', me_id,
    'playerLimit', selected_room.player_limit,
    'level', selected_room.level_code,
    'mode', selected_room.mode_code,
    'questionCount', selected_room.question_count,
    'status', selected_room.status,
    'currentQuestion', selected_room.current_question,
    'currentAttempt', selected_room.current_attempt,
    'activePlayerId', selected_room.active_player_id,
    'buzzerPlayerId', selected_room.buzzer_player_id,
    'eligibleBuzzerSeats', to_jsonb(eligible_seats),
    'phaseDeadline', selected_room.phase_deadline,
    'teamAScore', selected_room.team_a_score,
    'teamBScore', selected_room.team_b_score,
    'lastResult', selected_room.last_result,
    'version', selected_room.version,
    'question', selected_question,
    'players', players_json
  );
end;
$$;

create or replace function public.periodic_battle_create(
  p_player_limit integer,
  p_level_code text,
  p_mode_code text,
  p_question_count integer,
  p_questions jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  actor public.contact_book_profiles%rowtype;
  new_room_id uuid;
  new_code text;
  question_item jsonb;
  question_position integer := 0;
  tries integer := 0;
  question_id uuid;
begin
  select * into actor from public.contact_book_profiles
  where id = auth.uid() and approval_status = 'approved' and is_active;
  if actor.id is null then raise exception using errcode = '42501', message = 'approved_profile_required'; end if;
  if p_player_limit not in (2, 4) then raise exception using errcode = '22023', message = 'invalid_player_limit'; end if;
  if p_level_code not in ('beginner', 'advanced', 'challenge', 'complete') then raise exception using errcode = '22023', message = 'invalid_level'; end if;
  if p_mode_code not in ('name_symbol', 'symbol_name', 'locate', 'mixed') then raise exception using errcode = '22023', message = 'invalid_mode'; end if;
  if p_question_count < 4 or p_question_count > 40 or (p_player_limit = 4 and mod(p_question_count, 4) <> 0) then
    raise exception using errcode = '22023', message = 'invalid_question_count';
  end if;
  if jsonb_typeof(p_questions) <> 'array' or jsonb_array_length(p_questions) <> p_question_count then
    raise exception using errcode = '22023', message = 'invalid_questions';
  end if;

  loop
    tries := tries + 1;
    new_code := lpad(floor(random() * 10000)::integer::text, 4, '0');
    exit when not exists (
      select 1 from public.periodic_battle_rooms
      where room_code = new_code and status <> 'closed' and created_at > now() - interval '12 hours'
    );
    if tries >= 50 then raise exception using errcode = 'P0001', message = 'room_code_unavailable'; end if;
  end loop;

  insert into public.periodic_battle_rooms (
    room_code, host_profile_id, player_limit, level_code, mode_code, question_count
  ) values (
    new_code, actor.id, p_player_limit, p_level_code, p_mode_code, p_question_count
  ) returning id into new_room_id;

  insert into public.periodic_battle_players (
    room_id, profile_id, display_name, seat_number, team_code
  ) values (
    new_room_id, actor.id, actor.display_name, 1, case when p_player_limit = 2 then 'A' else null end
  );

  for question_item in select value from jsonb_array_elements(p_questions)
  loop
    question_position := question_position + 1;
    if question_item->>'mode' not in ('name_symbol', 'symbol_name', 'locate')
      or nullif(trim(question_item->>'prompt'), '') is null
      or nullif(question_item->>'answer', '') is null then
      raise exception using errcode = '22023', message = 'invalid_question_item';
    end if;
    insert into public.periodic_battle_questions(room_id, position, mode_code, prompt, choices)
    values (
      new_room_id,
      question_position,
      question_item->>'mode',
      question_item->>'prompt',
      coalesce(question_item->'choices', '[]'::jsonb)
    ) returning id into question_id;
    insert into public.periodic_battle_answers(question_id, correct_answer)
    values (question_id, question_item->>'answer');
  end loop;

  return public.periodic_battle_snapshot(new_room_id);
end;
$$;

create or replace function public.periodic_battle_join(p_room_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  actor public.contact_book_profiles%rowtype;
  selected_room public.periodic_battle_rooms%rowtype;
  existing_player uuid;
  selected_seat integer;
begin
  select * into actor from public.contact_book_profiles
  where id = auth.uid() and approval_status = 'approved' and is_active;
  if actor.id is null then raise exception using errcode = '42501', message = 'approved_profile_required'; end if;

  select * into selected_room
  from public.periodic_battle_rooms
  where room_code = trim(p_room_code) and status <> 'closed' and created_at > now() - interval '12 hours'
  order by created_at desc limit 1 for update;
  if selected_room.id is null then raise exception using errcode = 'P0001', message = 'battle_room_not_found'; end if;

  select id into existing_player from public.periodic_battle_players
  where room_id = selected_room.id and profile_id = actor.id and not is_replaced limit 1;
  if existing_player is not null then
    update public.periodic_battle_players set last_seen_at = now() where id = existing_player;
    return public.periodic_battle_snapshot(selected_room.id);
  end if;
  if selected_room.status <> 'lobby' then raise exception using errcode = 'P0001', message = 'battle_already_started'; end if;

  select seat into selected_seat
  from generate_series(1, selected_room.player_limit) seat
  where not exists (
    select 1 from public.periodic_battle_players player
    where player.room_id = selected_room.id and player.seat_number = seat and not player.is_replaced
  )
  order by seat limit 1;
  if selected_seat is null then raise exception using errcode = 'P0001', message = 'battle_room_full'; end if;

  insert into public.periodic_battle_players(room_id, profile_id, display_name, seat_number, team_code)
  values (selected_room.id, actor.id, actor.display_name, selected_seat,
    case when selected_room.player_limit = 2 then case when selected_seat = 1 then 'A' else 'B' end else null end);
  update public.periodic_battle_rooms set version = version + 1, updated_at = now() where id = selected_room.id;
  return public.periodic_battle_snapshot(selected_room.id);
end;
$$;

create or replace function public.periodic_battle_heartbeat(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.periodic_battle_players
  set last_seen_at = now()
  where room_id = p_room_id and profile_id = auth.uid() and not is_replaced;
  if not found then raise exception using errcode = '42501', message = 'battle_player_not_found'; end if;
  return public.periodic_battle_snapshot(p_room_id);
end;
$$;

create or replace function public.periodic_battle_fill_ai(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.periodic_battle_rooms%rowtype;
  selected_seat integer;
  stale_player public.periodic_battle_players%rowtype;
  ai_player_id uuid;
  ai_number integer;
begin
  select * into selected_room from public.periodic_battle_rooms where id = p_room_id for update;
  if selected_room.id is null or selected_room.host_profile_id <> auth.uid() then
    raise exception using errcode = '42501', message = 'battle_host_required';
  end if;
  if selected_room.status = 'finished' or selected_room.status = 'closed' then
    raise exception using errcode = 'P0001', message = 'battle_finished';
  end if;

  select seat into selected_seat from generate_series(1, selected_room.player_limit) seat
  where not exists (
    select 1 from public.periodic_battle_players player
    where player.room_id = p_room_id and player.seat_number = seat and not player.is_replaced
  ) order by seat limit 1;

  if selected_seat is null then
    select * into stale_player from public.periodic_battle_players player
    where player.room_id = p_room_id and not player.is_ai and not player.is_replaced
      and player.profile_id <> auth.uid() and player.last_seen_at < now() - interval '30 seconds'
    order by player.last_seen_at limit 1 for update;
    if stale_player.id is null then raise exception using errcode = 'P0001', message = 'no_ai_seat_available'; end if;
    selected_seat := stale_player.seat_number;
    update public.periodic_battle_players set is_replaced = true, seat_number = seat_number + 10 where id = stale_player.id;
  end if;

  ai_number := 1 + (select count(*) from public.periodic_battle_players where room_id = p_room_id and is_ai and not is_replaced);
  insert into public.periodic_battle_players(room_id, display_name, seat_number, team_code, is_ai)
  values (
    p_room_id, 'AI 挑戰者 ' || ai_number, selected_seat,
    case when selected_room.player_limit = 2 then case when selected_seat = 1 then 'A' else 'B' end else null end,
    true
  ) returning id into ai_player_id;
  insert into public.periodic_battle_ai_settings(player_id, accuracy)
  values (ai_player_id, 60 + floor(random() * 21)::integer);
  update public.periodic_battle_rooms set
    active_player_id = case when active_player_id = stale_player.id then ai_player_id else active_player_id end,
    buzzer_player_id = case when buzzer_player_id = stale_player.id then ai_player_id else buzzer_player_id end,
    ai_action_at = case
      when active_player_id = stale_player.id then now() + ((600 + floor(random() * 900))::text || ' milliseconds')::interval
      when status = 'buzzing' and selected_seat = any(public.periodic_battle_initial_seats(player_limit, current_question))
        then now() + ((800 + floor(random() * 1700))::text || ' milliseconds')::interval
      else ai_action_at
    end,
    version = version + 1,
    updated_at = now()
  where id = p_room_id;
  return public.periodic_battle_snapshot(p_room_id);
end;
$$;

create or replace function public.periodic_battle_start(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.periodic_battle_rooms%rowtype;
  player_count integer;
  player_row record;
  slot integer := 0;
begin
  select * into selected_room from public.periodic_battle_rooms where id = p_room_id for update;
  if selected_room.id is null or selected_room.host_profile_id <> auth.uid() then
    raise exception using errcode = '42501', message = 'battle_host_required';
  end if;
  if selected_room.status <> 'lobby' then raise exception using errcode = 'P0001', message = 'battle_already_started'; end if;
  select count(*) into player_count from public.periodic_battle_players where room_id = p_room_id and not is_replaced;
  if player_count <> selected_room.player_limit then raise exception using errcode = 'P0001', message = 'battle_players_incomplete'; end if;

  update public.periodic_battle_players set seat_number = seat_number + 10 where room_id = p_room_id and not is_replaced;
  for player_row in select id from public.periodic_battle_players where room_id = p_room_id and not is_replaced order by random()
  loop
    slot := slot + 1;
    update public.periodic_battle_players
    set seat_number = slot,
        team_code = case when selected_room.player_limit = 2 then case when slot = 1 then 'A' else 'B' end
                         when slot <= 2 then 'A' else 'B' end
    where id = player_row.id;
  end loop;

  update public.periodic_battle_rooms set
    status = 'thinking', current_question = 1, current_attempt = 0,
    active_player_id = null, buzzer_player_id = null, attempt_order = '{}',
    phase_deadline = now() + interval '3 seconds', ai_action_at = null,
    team_a_score = 0, team_b_score = 0, last_result = null,
    started_at = now(), version = version + 1, updated_at = now()
  where id = p_room_id;
  return public.periodic_battle_snapshot(p_room_id);
end;
$$;

create or replace function public.periodic_battle_set_answerer(
  p_room_id uuid,
  p_player_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.periodic_battle_rooms%rowtype;
  winner public.periodic_battle_players%rowtype;
  eligible smallint[];
  opponent_seat smallint;
  teammate_seat smallint;
  remaining_seat smallint;
  next_order smallint[];
  is_ai_player boolean;
begin
  select * into selected_room from public.periodic_battle_rooms where id = p_room_id for update;
  select * into winner from public.periodic_battle_players where id = p_player_id and room_id = p_room_id and not is_replaced;
  eligible := public.periodic_battle_initial_seats(selected_room.player_limit, selected_room.current_question);
  if winner.id is null or not winner.seat_number = any(eligible) then
    raise exception using errcode = '42501', message = 'player_not_buzzer_eligible';
  end if;
  opponent_seat := case when eligible[1] = winner.seat_number then eligible[2] else eligible[1] end;
  if selected_room.player_limit = 2 then
    next_order := array[winner.seat_number, opponent_seat]::smallint[];
  else
    select seat_number into teammate_seat from public.periodic_battle_players
    where room_id = p_room_id and team_code = winner.team_code and id <> winner.id and not is_replaced limit 1;
    select seat_number into remaining_seat from public.periodic_battle_players
    where room_id = p_room_id and seat_number <> all(array[winner.seat_number, opponent_seat, teammate_seat]::smallint[]) and not is_replaced limit 1;
    next_order := array[winner.seat_number, opponent_seat, teammate_seat, remaining_seat]::smallint[];
  end if;
  select is_ai into is_ai_player from public.periodic_battle_players where id = p_player_id;
  update public.periodic_battle_rooms set
    status = 'answering', buzzer_player_id = p_player_id, active_player_id = p_player_id,
    attempt_order = next_order, current_attempt = 1,
    phase_deadline = now() + interval '5 seconds',
    ai_action_at = case when is_ai_player then now() + ((600 + floor(random() * 900))::text || ' milliseconds')::interval else null end,
    version = version + 1, updated_at = now()
  where id = p_room_id;
end;
$$;

create or replace function public.periodic_battle_apply_attempt(
  p_room_id uuid,
  p_player_id uuid,
  p_answer text,
  p_is_timeout boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.periodic_battle_rooms%rowtype;
  selected_player public.periodic_battle_players%rowtype;
  correct_answer text;
  answer_correct boolean;
  score_change integer;
  next_seat integer;
  next_player public.periodic_battle_players%rowtype;
begin
  select * into selected_room from public.periodic_battle_rooms where id = p_room_id for update;
  select * into selected_player from public.periodic_battle_players where id = p_player_id and room_id = p_room_id and not is_replaced;
  if selected_room.status <> 'answering' or selected_room.active_player_id <> p_player_id or selected_player.id is null then
    raise exception using errcode = 'P0001', message = 'not_active_answerer';
  end if;
  select answer.correct_answer into correct_answer
  from public.periodic_battle_questions question
  join public.periodic_battle_answers answer on answer.question_id = question.id
  where question.room_id = p_room_id and question.position = selected_room.current_question;

  answer_correct := not p_is_timeout and coalesce(p_answer, '') = correct_answer;
  score_change := case when answer_correct then case selected_room.current_attempt when 1 then 3 when 2 then 2 else 1 end else -1 end;
  insert into public.periodic_battle_attempts(
    room_id, question_position, player_id, attempt_number, submitted_answer, is_correct, is_timeout, score_delta
  ) values (
    p_room_id, selected_room.current_question, p_player_id, selected_room.current_attempt,
    p_answer, answer_correct, p_is_timeout, score_change
  ) on conflict (room_id, question_position, player_id) do nothing;

  update public.periodic_battle_rooms set
    team_a_score = team_a_score + case when selected_player.team_code = 'A' then score_change else 0 end,
    team_b_score = team_b_score + case when selected_player.team_code = 'B' then score_change else 0 end,
    last_result = jsonb_build_object(
      'playerId', selected_player.id, 'displayName', selected_player.display_name,
      'isCorrect', answer_correct, 'isTimeout', p_is_timeout, 'scoreDelta', score_change,
      'correctAnswer', case when answer_correct then correct_answer else null end
    ),
    version = version + 1, updated_at = now()
  where id = p_room_id;

  if answer_correct or selected_room.current_attempt >= array_length(selected_room.attempt_order, 1) then
    update public.periodic_battle_rooms set
      status = 'resolved', active_player_id = null,
      phase_deadline = now() + interval '2500 milliseconds', ai_action_at = null,
      last_result = last_result || jsonb_build_object('correctAnswer', correct_answer, 'exhausted', not answer_correct)
    where id = p_room_id;
    return;
  end if;

  next_seat := selected_room.attempt_order[selected_room.current_attempt + 1];
  select * into next_player from public.periodic_battle_players
  where room_id = p_room_id and seat_number = next_seat and not is_replaced;
  update public.periodic_battle_rooms set
    active_player_id = next_player.id,
    current_attempt = current_attempt + 1,
    phase_deadline = now() + interval '5 seconds',
    ai_action_at = case when next_player.is_ai then now() + ((600 + floor(random() * 900))::text || ' milliseconds')::interval else null end
  where id = p_room_id;
end;
$$;

create or replace function public.periodic_battle_advance(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.periodic_battle_rooms%rowtype;
  eligible smallint[];
  ai_player_id uuid;
  ai_accuracy integer;
  correct_answer text;
begin
  if not public.periodic_battle_is_participant(p_room_id) then
    raise exception using errcode = '42501', message = 'battle_room_access_denied';
  end if;
  select * into selected_room from public.periodic_battle_rooms where id = p_room_id for update;

  if selected_room.status = 'thinking' and selected_room.phase_deadline <= now() then
    eligible := public.periodic_battle_initial_seats(selected_room.player_limit, selected_room.current_question);
    select player.id into ai_player_id from public.periodic_battle_players player
    where player.room_id = p_room_id and player.is_ai and not player.is_replaced and player.seat_number = any(eligible)
    order by random() limit 1;
    update public.periodic_battle_rooms set
      status = 'buzzing', phase_deadline = null,
      ai_action_at = case when ai_player_id is not null then now() + ((800 + floor(random() * 1700))::text || ' milliseconds')::interval else null end,
      version = version + 1, updated_at = now()
    where id = p_room_id;
  elsif selected_room.status = 'buzzing' and selected_room.ai_action_at is not null and selected_room.ai_action_at <= now() then
    eligible := public.periodic_battle_initial_seats(selected_room.player_limit, selected_room.current_question);
    select player.id into ai_player_id from public.periodic_battle_players player
    where player.room_id = p_room_id and player.is_ai and not player.is_replaced and player.seat_number = any(eligible)
    order by random() limit 1;
    if ai_player_id is not null then perform public.periodic_battle_set_answerer(p_room_id, ai_player_id); end if;
  elsif selected_room.status = 'answering' and selected_room.active_player_id is not null then
    select setting.accuracy into ai_accuracy
    from public.periodic_battle_ai_settings setting
    where setting.player_id = selected_room.active_player_id;
    if ai_accuracy is not null and selected_room.ai_action_at is not null and selected_room.ai_action_at <= now() then
      select answer.correct_answer into correct_answer
      from public.periodic_battle_questions question
      join public.periodic_battle_answers answer on answer.question_id = question.id
      where question.room_id = p_room_id and question.position = selected_room.current_question;
      perform public.periodic_battle_apply_attempt(
        p_room_id, selected_room.active_player_id,
        case when floor(random() * 100)::integer < ai_accuracy then correct_answer else '__AI_WRONG__' end,
        false
      );
    elsif selected_room.phase_deadline <= now() then
      perform public.periodic_battle_apply_attempt(p_room_id, selected_room.active_player_id, null, true);
    end if;
  elsif selected_room.status = 'resolved' and selected_room.phase_deadline <= now() then
    if selected_room.current_question >= selected_room.question_count then
      update public.periodic_battle_rooms set
        status = 'finished', phase_deadline = null, ai_action_at = null,
        finished_at = now(), version = version + 1, updated_at = now()
      where id = p_room_id;
    else
      update public.periodic_battle_rooms set
        status = 'thinking', current_question = current_question + 1,
        current_attempt = 0, active_player_id = null, buzzer_player_id = null,
        attempt_order = '{}', phase_deadline = now() + interval '3 seconds',
        ai_action_at = null, last_result = null, version = version + 1, updated_at = now()
      where id = p_room_id;
    end if;
  end if;
  return public.periodic_battle_snapshot(p_room_id);
end;
$$;

create or replace function public.periodic_battle_buzz(p_room_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.periodic_battle_rooms%rowtype;
  selected_player uuid;
begin
  select * into selected_room from public.periodic_battle_rooms where id = p_room_id for update;
  if selected_room.status <> 'buzzing' then raise exception using errcode = 'P0001', message = 'buzzer_closed'; end if;
  select player.id into selected_player from public.periodic_battle_players player
  where player.room_id = p_room_id and player.profile_id = auth.uid() and not player.is_replaced and not player.is_ai;
  if selected_player is null then raise exception using errcode = '42501', message = 'battle_player_not_found'; end if;
  perform public.periodic_battle_set_answerer(p_room_id, selected_player);
  return public.periodic_battle_snapshot(p_room_id);
end;
$$;

create or replace function public.periodic_battle_answer(p_room_id uuid, p_answer text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  selected_room public.periodic_battle_rooms%rowtype;
  selected_player uuid;
begin
  select * into selected_room from public.periodic_battle_rooms where id = p_room_id for update;
  select player.id into selected_player from public.periodic_battle_players player
  where player.room_id = p_room_id and player.profile_id = auth.uid() and not player.is_replaced and not player.is_ai;
  if selected_player is null or selected_room.active_player_id <> selected_player then
    raise exception using errcode = '42501', message = 'not_active_answerer';
  end if;
  if selected_room.phase_deadline <= now() then
    perform public.periodic_battle_apply_attempt(p_room_id, selected_player, null, true);
  else
    perform public.periodic_battle_apply_attempt(p_room_id, selected_player, p_answer, false);
  end if;
  return public.periodic_battle_snapshot(p_room_id);
end;
$$;

revoke all on table public.periodic_battle_answers from anon, authenticated;
revoke all on table public.periodic_battle_ai_settings from anon, authenticated;
revoke all on function public.periodic_battle_set_answerer(uuid, uuid) from public;
revoke all on function public.periodic_battle_apply_attempt(uuid, uuid, text, boolean) from public;
revoke all on function public.periodic_battle_is_participant(uuid) from public;
revoke all on function public.periodic_battle_initial_seats(integer, integer) from public;
grant execute on function public.periodic_battle_snapshot(uuid) to authenticated;
grant execute on function public.periodic_battle_is_participant(uuid) to authenticated;
grant execute on function public.periodic_battle_create(integer, text, text, integer, jsonb) to authenticated;
grant execute on function public.periodic_battle_join(text) to authenticated;
grant execute on function public.periodic_battle_heartbeat(uuid) to authenticated;
grant execute on function public.periodic_battle_fill_ai(uuid) to authenticated;
grant execute on function public.periodic_battle_start(uuid) to authenticated;
grant execute on function public.periodic_battle_advance(uuid) to authenticated;
grant execute on function public.periodic_battle_buzz(uuid) to authenticated;
grant execute on function public.periodic_battle_answer(uuid, text) to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'periodic_battle_rooms'
  ) then alter publication supabase_realtime add table public.periodic_battle_rooms; end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'periodic_battle_players'
  ) then alter publication supabase_realtime add table public.periodic_battle_players; end if;
end $$;
