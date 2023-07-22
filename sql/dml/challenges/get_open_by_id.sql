SELECT
    {challenge_id} as id,
    ch.owner_ref as owner_ref,
    ch.challenge_type as challenge_type,
    NULL as callee_ref,
    ch.accepting_side_color as accepting_side_color,
    ch.custom_starting_sip as custom_starting_sip,
    ch.rated as rated,
    ch.active as active,
    ch.resulting_game_id as resulting_game_id,
    tc.start_secs as start_secs,
    tc.increment_secs as increment_secs,
    elo_data.elo as owner_elo,
    elo_data.relevant_rated_games_cnt as owner_relevant_rated_games_cnt
FROM challenge.challenge as ch
LEFT JOIN challenge.fischer_time_control as tc
ON ch.id = tc.challenge_id
LEFT JOIN player.v_actual_ranked_data as elo_data
ON ch.time_control_type = elo_data.time_control_type
AND ch.owner_ref = elo_data.player_login
WHERE ch.id = {challenge_id}
AND ch.challenge_type != 'direct'