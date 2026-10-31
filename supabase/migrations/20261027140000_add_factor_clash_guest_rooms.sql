-- 因式交鋒第二階段：免登入雙人房間。
-- 座位權限只靠高熵 token 驗證；快照函式只回傳自己的題目與對手公開進度。

create table if not exists public.factor_clash_rooms (
  id uuid primary key default gen_random_uuid(),
  room_code text not null unique check (room_code ~ '^[0-9]{6}$'),
  status text not null default 'waiting' check (status in ('waiting','playing','finished','closed')),
  host_player_id uuid,
  mode text check (mode in ('area','cross')),
  difficulty text check (difficulty in ('basic','advanced')),
  question_count smallint not null default 10 check (question_count = 10),
  version integer not null default 1,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.factor_clash_room_players (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.factor_clash_rooms(id) on delete cascade,
  nickname citext not null,
  seat_no smallint not null check (seat_no in (1,2)),
  token_hash text not null,
  questions jsonb not null default '[]'::jsonb,
  progress smallint not null default 0 check (progress between 0 and 10),
  score smallint not null default 0 check (score between 0 and 30),
  first_try_correct smallint not null default 0 check (first_try_correct between 0 and 10),
  total_elapsed_ms integer not null default 0 check (total_elapsed_ms >= 0),
  timeout_count smallint not null default 0 check (timeout_count between 0 and 10),
  status text not null default 'connected' check (status in ('connected','finished','forfeited','left')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (room_id, nickname),
  unique (room_id, seat_no)
);

alter table public.factor_clash_rooms
  add constraint factor_clash_rooms_host_player_fk foreign key (host_player_id)
  references public.factor_clash_room_players(id) on delete set null;

create index if not exists factor_clash_room_players_room_idx
  on public.factor_clash_room_players(room_id, seat_no);

alter table public.factor_clash_rooms enable row level security;
alter table public.factor_clash_room_players enable row level security;
revoke all on table public.factor_clash_rooms from public, anon, authenticated;
revoke all on table public.factor_clash_room_players from public, anon, authenticated;

create or replace function public.factor_clash_token_hash(p_token text)
returns text language sql immutable set search_path = public
as $$ select encode(extensions.digest(coalesce(p_token,''), 'sha256'), 'hex') $$;

create or replace function public.factor_clash_create_room(p_nickname text)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare clean_name text := trim(coalesce(p_nickname,'')); code text; token text;
  new_room public.factor_clash_rooms%rowtype; new_player public.factor_clash_room_players%rowtype;
begin
  if char_length(clean_name) not between 1 and 10 then raise exception 'factor_nickname_invalid'; end if;
  loop
    code := lpad((floor(random()*1000000))::integer::text,6,'0');
    exit when not exists(select 1 from public.factor_clash_rooms where room_code=code);
  end loop;
  token := encode(extensions.gen_random_bytes(24),'hex');
  insert into public.factor_clash_rooms(room_code) values(code) returning * into new_room;
  insert into public.factor_clash_room_players(room_id,nickname,seat_no,token_hash)
    values(new_room.id,clean_name,1,public.factor_clash_token_hash(token)) returning * into new_player;
  update public.factor_clash_rooms set host_player_id=new_player.id where id=new_room.id;
  return jsonb_build_object('roomCode',code,'seatToken',token);
end $$;

create or replace function public.factor_clash_join_room(p_room_code text,p_nickname text)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare clean_name text := trim(coalesce(p_nickname,'')); token text; selected_room public.factor_clash_rooms%rowtype;
begin
  if char_length(clean_name) not between 1 and 10 then raise exception 'factor_nickname_invalid'; end if;
  select * into selected_room from public.factor_clash_rooms where room_code=p_room_code for update;
  if not found then raise exception 'factor_room_not_found'; end if;
  if selected_room.status <> 'waiting' then raise exception 'factor_room_started'; end if;
  if exists(select 1 from public.factor_clash_room_players where room_id=selected_room.id and nickname=clean_name) then raise exception 'factor_duplicate_nickname'; end if;
  if (select count(*) from public.factor_clash_room_players where room_id=selected_room.id and status<>'left') >= 2 then raise exception 'factor_room_full'; end if;
  token := encode(extensions.gen_random_bytes(24),'hex');
  insert into public.factor_clash_room_players(room_id,nickname,seat_no,token_hash)
    values(selected_room.id,clean_name,2,public.factor_clash_token_hash(token));
  update public.factor_clash_rooms set version=version+1,updated_at=now() where id=selected_room.id;
  return jsonb_build_object('roomCode',selected_room.room_code,'seatToken',token);
end $$;

create or replace function public.factor_clash_room_snapshot(p_room_code text,p_seat_token text)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare selected_room public.factor_clash_rooms%rowtype; me public.factor_clash_room_players%rowtype;
  opponent public.factor_clash_room_players%rowtype;
begin
  select * into selected_room from public.factor_clash_rooms where room_code=p_room_code;
  if not found then raise exception 'factor_room_not_found'; end if;
  select * into me from public.factor_clash_room_players
    where room_id=selected_room.id and token_hash=public.factor_clash_token_hash(p_seat_token);
  if not found then raise exception 'factor_seat_invalid'; end if;
  update public.factor_clash_room_players set last_seen_at=now() where id=me.id;
  select * into opponent from public.factor_clash_room_players where room_id=selected_room.id and id<>me.id and status<>'left' order by seat_no limit 1;
  if selected_room.status='playing' and opponent.id is not null and opponent.last_seen_at < now()-interval '3 minutes' and opponent.status='connected' then
    update public.factor_clash_room_players set status='forfeited' where id=opponent.id;
    update public.factor_clash_rooms set status='finished',finished_at=now(),version=version+1,updated_at=now() where id=selected_room.id;
    selected_room.status := 'finished'; opponent.status := 'forfeited';
  end if;
  return jsonb_build_object(
    'room',jsonb_build_object('roomCode',selected_room.room_code,'status',selected_room.status,'mode',selected_room.mode,'difficulty',selected_room.difficulty,'questionCount',selected_room.question_count),
    'self',jsonb_build_object('id',me.id,'nickname',me.nickname,'seatNo',me.seat_no,'questions',me.questions,'progress',me.progress,'score',me.score,'firstTryCorrect',me.first_try_correct,'totalElapsedMs',me.total_elapsed_ms,'status',me.status),
    'opponent',case when opponent.id is null then null else jsonb_build_object('nickname',opponent.nickname,'progress',opponent.progress,'score',opponent.score,'firstTryCorrect',opponent.first_try_correct,'totalElapsedMs',opponent.total_elapsed_ms,'status',opponent.status,'online',opponent.last_seen_at >= now()-interval '10 seconds') end,
    'isHost',selected_room.host_player_id=me.id
  );
end $$;

create or replace function public.factor_clash_start_room(p_room_code text,p_seat_token text,p_mode text,p_difficulty text,p_host_questions jsonb,p_guest_questions jsonb)
returns boolean language plpgsql security definer set search_path = public
as $$
declare selected_room public.factor_clash_rooms%rowtype; me public.factor_clash_room_players%rowtype;
begin
  select * into selected_room from public.factor_clash_rooms where room_code=p_room_code for update;
  if not found then raise exception 'factor_room_not_found'; end if;
  select * into me from public.factor_clash_room_players where room_id=selected_room.id and token_hash=public.factor_clash_token_hash(p_seat_token);
  if me.id is null then raise exception 'factor_seat_invalid'; end if;
  if selected_room.host_player_id<>me.id then raise exception 'factor_host_required'; end if;
  if (select count(*) from public.factor_clash_room_players where room_id=selected_room.id and status='connected')<>2 then raise exception 'factor_players_incomplete'; end if;
  if p_mode not in ('area','cross') or p_difficulty not in ('basic','advanced') or jsonb_array_length(p_host_questions)<>10 or jsonb_array_length(p_guest_questions)<>10 then raise exception 'factor_settings_invalid'; end if;
  update public.factor_clash_room_players set questions=case when seat_no=1 then p_host_questions else p_guest_questions end,
    progress=0,score=0,first_try_correct=0,total_elapsed_ms=0,timeout_count=0,status='connected',last_seen_at=now()
    where room_id=selected_room.id;
  update public.factor_clash_rooms set status='playing',mode=p_mode,difficulty=p_difficulty,started_at=now(),finished_at=null,version=version+1,updated_at=now() where id=selected_room.id;
  return true;
end $$;

create or replace function public.factor_clash_report_question(p_room_code text,p_seat_token text,p_question_number integer,p_points integer,p_first_try boolean,p_elapsed_ms integer,p_timed_out boolean)
returns boolean language plpgsql security definer set search_path = public
as $$
declare selected_room public.factor_clash_rooms%rowtype; me public.factor_clash_room_players%rowtype;
begin
  select * into selected_room from public.factor_clash_rooms where room_code=p_room_code for update;
  if not found then raise exception 'factor_room_not_found'; end if;
  select * into me from public.factor_clash_room_players where room_id=selected_room.id and token_hash=public.factor_clash_token_hash(p_seat_token) for update;
  if me.id is null then raise exception 'factor_seat_invalid'; end if;
  if selected_room.status<>'playing' or p_question_number<>me.progress+1 then raise exception 'factor_submission_order_invalid'; end if;
  if p_points not in (0,1,3) or p_elapsed_ms<0 then raise exception 'factor_submission_invalid'; end if;
  update public.factor_clash_room_players set progress=p_question_number,score=score+p_points,
    first_try_correct=first_try_correct+case when p_first_try and p_points=3 then 1 else 0 end,
    total_elapsed_ms=total_elapsed_ms+p_elapsed_ms,timeout_count=timeout_count+case when p_timed_out then 1 else 0 end,
    status=case when p_question_number=10 then 'finished' else status end,last_seen_at=now() where id=me.id;
  if not exists(select 1 from public.factor_clash_room_players where room_id=selected_room.id and status='connected') then
    update public.factor_clash_rooms set status='finished',finished_at=now(),version=version+1,updated_at=now() where id=selected_room.id;
  else update public.factor_clash_rooms set version=version+1,updated_at=now() where id=selected_room.id; end if;
  return true;
end $$;

create or replace function public.factor_clash_leave_room(p_room_code text,p_seat_token text)
returns boolean language plpgsql security definer set search_path = public
as $$
declare selected_room public.factor_clash_rooms%rowtype; me public.factor_clash_room_players%rowtype;
begin
  select * into selected_room from public.factor_clash_rooms where room_code=p_room_code for update;
  if not found then raise exception 'factor_room_not_found'; end if;
  select * into me from public.factor_clash_room_players where room_id=selected_room.id and token_hash=public.factor_clash_token_hash(p_seat_token);
  if me.id is null then raise exception 'factor_seat_invalid'; end if;
  update public.factor_clash_room_players set status=case when selected_room.status='playing' then 'forfeited' else 'left' end,last_seen_at=now() where id=me.id;
  update public.factor_clash_rooms set status=case when selected_room.status='playing' then 'finished' else status end,
    finished_at=case when selected_room.status='playing' then now() else finished_at end,version=version+1,updated_at=now() where id=selected_room.id;
  return true;
end $$;

create or replace function public.factor_clash_release_offline_seat(p_room_code text,p_seat_token text)
returns boolean language plpgsql security definer set search_path = public
as $$
declare selected_room public.factor_clash_rooms%rowtype; me public.factor_clash_room_players%rowtype;
begin
  select * into selected_room from public.factor_clash_rooms where room_code=p_room_code for update;
  select * into me from public.factor_clash_room_players where room_id=selected_room.id and token_hash=public.factor_clash_token_hash(p_seat_token);
  if selected_room.host_player_id<>me.id then raise exception 'factor_host_required'; end if;
  if selected_room.status<>'waiting' then return false; end if;
  delete from public.factor_clash_room_players where room_id=selected_room.id and seat_no=2 and (status='left' or last_seen_at<now()-interval '3 minutes');
  update public.factor_clash_rooms set version=version+1,updated_at=now() where id=selected_room.id;
  return true;
end $$;

revoke all on function public.factor_clash_token_hash(text) from public,anon,authenticated;
revoke all on function public.factor_clash_create_room(text) from public;
revoke all on function public.factor_clash_join_room(text,text) from public;
revoke all on function public.factor_clash_room_snapshot(text,text) from public;
revoke all on function public.factor_clash_start_room(text,text,text,text,jsonb,jsonb) from public;
revoke all on function public.factor_clash_report_question(text,text,integer,integer,boolean,integer,boolean) from public;
revoke all on function public.factor_clash_leave_room(text,text) from public;
revoke all on function public.factor_clash_release_offline_seat(text,text) from public;
grant execute on function public.factor_clash_create_room(text) to anon,authenticated;
grant execute on function public.factor_clash_join_room(text,text) to anon,authenticated;
grant execute on function public.factor_clash_room_snapshot(text,text) to anon,authenticated;
grant execute on function public.factor_clash_start_room(text,text,text,text,jsonb,jsonb) to anon,authenticated;
grant execute on function public.factor_clash_report_question(text,text,integer,integer,boolean,integer,boolean) to anon,authenticated;
grant execute on function public.factor_clash_leave_room(text,text) to anon,authenticated;
grant execute on function public.factor_clash_release_offline_seat(text,text) to anon,authenticated;
