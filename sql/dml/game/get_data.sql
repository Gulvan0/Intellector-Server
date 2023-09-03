SELECT
    game.id as id,
    game.white_player_ref as white_player_ref,
    game.black_player_ref as black_player_ref,
    game.time_control_type as time_control_type,
    game.rated as rated,
    game.start_ts as start_ts,
    game.custom_starting_sip as custom_starting_sip,
    game.most_recent_sip as most_recent_sip,
    game.outcome_type as outcome_type,
    game.winner_color as winner_color,
    tc.start_secs as start_secs,
    tc.increment_secs as increment_secs,
    white_prog.elo as white_elo,
    COALESCE(white_prog.ranked_games_played, 0) as white_ranked_games_cnt,
    black_prog.elo as black_elo,
    COALESCE(black_prog.ranked_games_played, 0) as black_ranked_games_cnt
FROM (
    SELECT
        *
    FROM game.game
    WHERE {condition}
) as game
LEFT JOIN game.fischer_time_control as tc
ON game.id = tc.game_id
LEFT JOIN player.ranked_progress as white_prog
ON game.white_player_ref = white_prog.player_login
AND game.time_control_type = white_prog.time_control_type
AND white_prog.ts = (
    SELECT
        MAX(inner_w_prog.ts)
    FROM player.ranked_progress as inner_w_prog
    WHERE inner_w_prog.player_login = game.white_player_ref
    AND inner_w_prog.time_control_type = game.time_control_type
    AND inner_w_prog.ts <= game.start_ts
)
LEFT JOIN player.ranked_progress as black_prog
ON game.black_player_ref = black_prog.player_login
AND game.time_control_type = black_prog.time_control_type
AND black_prog.ts = (
    SELECT
        MAX(inner_b_prog.ts)
    FROM player.ranked_progress as inner_b_prog
    WHERE inner_b_prog.player_login = game.black_player_ref
    AND inner_b_prog.time_control_type = game.time_control_type
    AND inner_b_prog.ts <= game.start_ts
)