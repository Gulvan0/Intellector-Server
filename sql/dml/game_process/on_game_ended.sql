INSERT INTO game.event
SELECT
    NULL as id,
    {game_id} as game_id,
    CURRENT_TIMESTAMP as ts;

INSERT INTO game.game_ended_event
SELECT
    {LAST_INSERT_ID} as event_id,
    {outcome_type} as outcome_type,
    {winner_color} as winner_color