INSERT INTO game.event
SELECT
    NULL as id,
    {game_id} as game_id,
    NULL as ts;

INSERT INTO game.time_added_event
SELECT
    {LAST_INSERT_ID} as event_id,
    {receiving_color} as receiving_color