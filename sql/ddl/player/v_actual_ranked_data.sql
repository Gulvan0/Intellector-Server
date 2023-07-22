CREATE VIEW player.v_actual_ranked_data AS
SELECT
    orig_table.player_login as player_login,
    orig_table.time_control_type as time_control_type,
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