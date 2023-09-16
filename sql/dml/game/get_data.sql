SELECT
    game.id AS id,
    game.white_player_ref AS white_player_ref,
    game.black_player_ref AS black_player_ref,
    game.time_control_type AS time_control_type,
    game.rated AS rated,
    game.start_ts AS start_ts,
    starting_sip_source.starting_sip AS starting_sip,
    most_recent_sip_source.most_recent_sip AS most_recent_sip,
    game.outcome_type AS outcome_type,
    game.winner_color AS winner_color,
    tc.start_secs AS start_secs,
    tc.increment_secs AS increment_secs,
    white_prog.elo AS white_elo,
    COALESCE(white_prog.ranked_games_played, 0) AS white_ranked_games_cnt,
    black_prog.elo AS black_elo,
    COALESCE(black_prog.ranked_games_played, 0) AS black_ranked_games_cnt
FROM (
    SELECT
        *
    FROM game.game
    WHERE
        ::if (concreteGameID != null)::
            id = ::concreteGameID::
        ::else::
            id IN (SELECT * FROM tmp.game_ids)
        ::end::
) AS game
LEFT JOIN game.fischer_time_control AS tc
ON game.id = tc.game_id
LEFT JOIN player.ranked_progress AS white_prog
ON game.white_player_ref = white_prog.player_login
AND game.time_control_type = white_prog.time_control_type
AND white_prog.ts = (
    SELECT
        MAX(inner_w_prog.ts)
    FROM player.ranked_progress AS inner_w_prog
    WHERE inner_w_prog.player_login = game.white_player_ref
    AND inner_w_prog.time_control_type = game.time_control_type
    AND inner_w_prog.ts <= game.start_ts
)
LEFT JOIN player.ranked_progress AS black_prog
ON game.black_player_ref = black_prog.player_login
AND game.time_control_type = black_prog.time_control_type
AND black_prog.ts = (
    SELECT
        MAX(inner_b_prog.ts)
    FROM player.ranked_progress AS inner_b_prog
    WHERE inner_b_prog.player_login = game.black_player_ref
    AND inner_b_prog.time_control_type = game.time_control_type
    AND inner_b_prog.ts <= game.start_ts
)
LEFT JOIN (
    SELECT
        game_id,
        sip AS starting_sip
    FROM game.encountered_situation
    WHERE ply_num = 0
) AS starting_sip_source
ON game.id = starting_sip_source.game_id
LEFT JOIN (
    SELECT
        outer_t.game_id AS game_id,
        outer_t.sip AS most_recent_sip
    FROM game.encountered_situation AS outer_t
    INNER JOIN (
        SELECT
            game_id,
            MAX(ply_num) as max_ply_num
        FROM game.encountered_situation
        GROUP BY game_id
    ) AS inner_t
    ON outer_t.game_id = inner_t.game_id
    AND outer_t.ply_num = inner_t.max_ply_num
) AS most_recent_sip_source
ON game.id = most_recent_sip_source.game_id