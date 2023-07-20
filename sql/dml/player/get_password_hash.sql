SELECT
    password_hash
FROM player.player
WHERE player_login = {player_login}
LIMIT 1