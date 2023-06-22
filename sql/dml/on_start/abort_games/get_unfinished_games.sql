SELECT
    all_events.game_id
FROM game.event AS all_events
LEFT JOIN game.game_ended_event AS game_ended_events
ON all_events.id = game_ended_events.event_id
WHERE game_ended_events.event_id IS NULL
UNION ALL
SELECT
    games.id
FROM game.game AS games
LEFT JOIN game.event AS all_events
ON games.id = all_events.game_id
WHERE all_events.game_id IS NULL