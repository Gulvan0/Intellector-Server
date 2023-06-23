INSERT INTO game.event
SELECT
    NULL as id,
    {game_id} as game_id,
    NULL as ts;

INSERT INTO game.offer_event
SELECT
    {LAST_INSERT_ID} as event_id,
    {offer_action} as offer_action,
    {offer_kind} as offer_kind,
    {sent_by} as sent_by