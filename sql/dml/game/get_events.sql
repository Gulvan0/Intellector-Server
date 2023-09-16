SELECT
    base_table.game_id AS game_id,
    base_table.ts AS event_ts,
    game_ended.outcome_type AS outcome_type,
    game_ended.winner_color AS winner_color,
    msg.author_ref AS author_ref,
    msg.msg_text AS msg_text,
    offer.offer_action AS offer_action,
    offer.offer_kind AS offer_kind,
    offer.sent_by AS sent_by,
    ply.departure_coord AS departure_coord,
    ply.destination_coord AS destination_coord,
    ply.morph_into AS morph_into,
    rollback_ev.cancelled_moves_cnt AS cancelled_moves_cnt,
    time_added.receiving_color AS receiving_color
FROM (
    SELECT
        game_id,
        id,
        ts
    FROM game.event
    WHERE
        ::if (concreteGameID != null)::
            game_id = ::concreteGameID::
        ::else::
            game_id IN (SELECT * FROM tmp.game_ids)
        ::end::
) AS base_table
LEFT JOIN game.game_ended_event AS game_ended
ON base_table.id = game_ended.event_id
LEFT JOIN game.message_event AS msg
ON base_table.id = msg.event_id
LEFT JOIN game.offer_event AS offer
ON base_table.id = offer.event_id
LEFT JOIN game.ply_event AS ply
ON base_table.id = ply.event_id
LEFT JOIN game.rollback_event AS rollback_ev
ON base_table.id = rollback_ev.event_id
LEFT JOIN game.time_added_event AS time_added
ON base_table.id = time_added.event_id
ORDER BY event_ts ASC