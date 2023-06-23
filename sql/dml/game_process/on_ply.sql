INSERT INTO game.event
SELECT
    NULL as id,
    {game_id} as game_id,
    NULL as ts;

INSERT INTO game.ply_event
SELECT
    {LAST_INSERT_ID} as event_id,
    {departure_coord} as departure_coord,
    {destination_coord} as destination_coord,
    {morph_into} as morph_into