SELECT
    ply_num AS max_ply_num,
    sip AS most_recent_sip
FROM game.encountered_situation
WHERE game_id = {game_id}
AND ply_num = (
    SELECT 
        MAX(ply_num)
    FROM game.encountered_situation
    WHERE game_id = {game_id}
)