INSERT INTO player.player
SELECT
    {player_login} as player_login,
    {password_hash} as password_hash