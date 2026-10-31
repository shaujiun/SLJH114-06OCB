-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default.  These
-- security-definer helpers must not be callable through PostgREST: in
-- particular, resolve_pending can impersonate a challenger and advance can
-- bypass the AI review step.  Internal calls still run as the function owner.
revoke all on function public.animal_equation_squarefree_part(integer) from public, anon, authenticated;
revoke all on function public.animal_equation_collect_expression_cards(jsonb) from public, anon, authenticated;
revoke all on function public.animal_equation_evaluate_expression(jsonb,uuid,uuid,jsonb) from public, anon, authenticated;
revoke all on function public.animal_equation_vector_multiply(numeric[],numeric[]) from public, anon, authenticated;
revoke all on function public.animal_equation_vector_add(numeric[],numeric[]) from public, anon, authenticated;
revoke all on function public.animal_equation_vector_subtract(numeric[],numeric[]) from public, anon, authenticated;
revoke all on function public.animal_equation_evaluate_exact(jsonb,uuid,uuid,jsonb) from public, anon, authenticated;
revoke all on function public.animal_equation_refill_hand(uuid,uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_next_player(uuid,uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_resolve_pending(uuid,uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_recalculate_scores(uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_finish_function_turn(uuid,uuid,uuid,text,uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_resolve_function_action(uuid,uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_ai_should_defend(uuid,uuid,uuid,uuid,text) from public, anon, authenticated;
revoke all on function public.animal_equation_respond_ai_if_needed(uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_count_valid_play() from public, anon, authenticated;

-- The legacy direct routes are used only from trusted functions now.
revoke all on function public.animal_equation_create(text) from public, anon, authenticated;
revoke all on function public.animal_equation_snapshot(uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_advance(uuid) from public, anon, authenticated;

-- Remove PUBLIC's implicit EXECUTE, then explicitly expose only client RPCs.
revoke all on function public.animal_equation_is_participant(uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_create_with_mode(text,integer) from public, anon, authenticated;
revoke all on function public.animal_equation_join(text,text) from public, anon, authenticated;
revoke all on function public.animal_equation_start(uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_heartbeat(uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_submit_radical(uuid,text,uuid[],jsonb,jsonb,jsonb) from public, anon, authenticated;
revoke all on function public.animal_equation_challenge(uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_submit_function(uuid,uuid,uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_respond_function(uuid,uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_run_ai_turn(uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_advance_with_ai(uuid) from public, anon, authenticated;
revoke all on function public.animal_equation_snapshot_with_ai(uuid) from public, anon, authenticated;

-- RLS policies call is_participant under the authenticated role.
grant execute on function public.animal_equation_is_participant(uuid) to authenticated;
grant execute on function public.animal_equation_create_with_mode(text,integer) to authenticated;
grant execute on function public.animal_equation_join(text,text) to authenticated;
grant execute on function public.animal_equation_start(uuid) to authenticated;
grant execute on function public.animal_equation_heartbeat(uuid) to authenticated;
grant execute on function public.animal_equation_submit_radical(uuid,text,uuid[],jsonb,jsonb,jsonb) to authenticated;
grant execute on function public.animal_equation_challenge(uuid) to authenticated;
grant execute on function public.animal_equation_submit_function(uuid,uuid,uuid) to authenticated;
grant execute on function public.animal_equation_respond_function(uuid,uuid) to authenticated;
grant execute on function public.animal_equation_run_ai_turn(uuid) to authenticated;
grant execute on function public.animal_equation_advance_with_ai(uuid) to authenticated;
grant execute on function public.animal_equation_snapshot_with_ai(uuid) to authenticated;
