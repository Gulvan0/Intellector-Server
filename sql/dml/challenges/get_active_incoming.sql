SELECT
    ch.id as id,
    ch.owner_ref as owner_ref,
    ch.accepting_side_color as accepting_side_color,
    ch.custom_starting_sip as custom_starting_sip,
    ch.rated as rated,
    tc.start_secs as start_secs,
    tc.increment_secs as increment_secs,
    elo_data.elo as owner_elo,
    elo_data.relevant_rated_games_cnt as owner_relevant_rated_games_cnt
FROM challenge.challenge as ch
LEFT JOIN challenge.fischer_time_control as tc
ON ch.id = tc.challenge_id
LEFT JOIN (
    SELECT
        orig_table.player_login,
        orig_table.time_control_type,
        orig_table.elo as elo,
        orig_table.ranked_games_played as relevant_rated_games_cnt
    FROM player.ranked_progress as orig_table
    INNER JOIN (
        SELECT
            player_login,
            time_control_type,
            MAX(ts) as ts
        FROM player.ranked_progress
        GROUP BY 
            player_login,
            time_control_type
    ) as grp_max
    ON orig_table.player_login = grp_max.player_login
    AND orig_table.time_control_type = grp_max.time_control_type
    AND orig_table.ts = grp_max.ts
) as elo_data
ON ch.time_control_type = elo_data.time_control_type
AND ch.owner_ref = elo_data.player_login
WHERE ch.active = 1
AND ch.challenge_type = 'direct'
AND ch.callee_ref = {callee_ref}