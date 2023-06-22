INSERT INTO log.antifraud
SELECT
    NULL as ts,
    {entry_type} as entry_type,
    {player_login} as player_login,
    {delta} as delta,
    {game_id} as game_id