INSERT INTO game.event
SELECT
    NULL as id,
    {game_id} as game_id,
    CURRENT_TIMESTAMP as ts;

INSERT INTO game.rollback_event
SELECT
    {LAST_INSERT_ID} as event_id,
    {cancelled_moves_cnt} as cancelled_moves_cnt