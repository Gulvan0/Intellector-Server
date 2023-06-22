INSERT INTO game.event
SELECT
    {event_id} as id,
    'abort' as outcome_type,
    NULL as winner_color;