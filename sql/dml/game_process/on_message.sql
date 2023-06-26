INSERT INTO game.event
SELECT
    NULL as id,
    {game_id} as game_id,
    CURRENT_TIMESTAMP as ts;

INSERT INTO game.message_event
SELECT
    {LAST_INSERT_ID} as event_id,
    {author_ref} as author_ref,
    {msg_text} as msg_text