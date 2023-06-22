INSERT INTO game.event
SELECT
    NULL as id,
    {game_id} as game_id,
    NULL as ts