SELECT
    {challenge_id} AS id,
    ch.owner_ref AS owner_ref,
    ch.challenge_type AS challenge_type,
    NULL AS callee_ref,
    ch.accepting_side_color AS accepting_side_color,
    ch.custom_starting_sip AS custom_starting_sip,
    ch.rated AS rated,
    ch.active AS active,
    ch.resulting_game_id AS resulting_game_id,
    tc.start_secs AS start_secs,
    tc.increment_secs AS increment_secs,
    elo_data.elo AS owner_elo,
    elo_data.relevant_rated_games_cnt AS owner_relevant_rated_games_cnt
FROM challenge.challenge AS ch
LEFT JOIN challenge.fischer_time_control AS tc
ON ch.id = tc.challenge_id
LEFT JOIN player.v_actual_ranked_data AS elo_data
ON ch.time_control_type = elo_data.time_control_type
AND ch.owner_ref = elo_data.player_login
WHERE ch.id = {challenge_id}
AND ch.challenge_type != 'direct'