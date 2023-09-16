SELECT
    max(id)
FROM game.game AS gm
LEFT JOIN game.event AS all_events
ON gm.id = all_events.game_id
LEFT JOIN game.game_ended_event AS game_ended_events
ON all_events.id = game_ended_events.event_id
WHERE game_ended_events.event_id IS NULL
AND (gm.white_player_ref = {player_ref} OR gm.white_player_ref = {player_ref})
AND time_control_type != 'correspondence'