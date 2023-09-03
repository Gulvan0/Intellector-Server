SELECT
    base_table.game_id as game_id,
    base_table.ts as event_ts,
    game_ended.outcome_type as outcome_type,
    game_ended.winner_color as winner_color,
    msg.author_ref as author_ref,
    msg.msg_text as msg_text,
    offer.offer_action as offer_action,
    offer.offer_kind as offer_kind,
    offer.sent_by as sent_by,
    ply.departure_coord as departure_coord,
    ply.destination_coord as destination_coord,
    ply.morph_into as morph_into,
    rollback_ev.cancelled_moves_cnt as cancelled_moves_cnt,
    time_added.receiving_color as receiving_color
FROM (
    SELECT
        game_id,
        id,
        ts
    FROM game.event
    WHERE {condition}
) as base_table
LEFT JOIN game.game_ended_event as game_ended
ON base_table.id = game_ended.event_id
LEFT JOIN game.message_event as msg
ON base_table.id = msg.event_id
LEFT JOIN game.offer_event as offer
ON base_table.id = offer.event_id
LEFT JOIN game.ply_event as ply
ON base_table.id = ply.event_id
LEFT JOIN game.rollback_event as rollback_ev
ON base_table.id = rollback_ev.event_id
LEFT JOIN game.time_added_event as time_added
ON base_table.id = time_added.event_id
ORDER BY event_ts ASC