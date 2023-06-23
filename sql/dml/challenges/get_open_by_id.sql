SELECT
    ch.owner_ref as owner_ref,
    ch.challenge_type as challenge_type,
    ch.accepting_side_color as accepting_side_color,
    ch.custom_starting_sip as custom_starting_sip,
    ch.rated as rated,
    ch.active as active,
    ch.resulting_game_id as resulting_game_id,
    tc.start_secs as start_secs,
    tc.increment_secs as increment_secs
FROM challenge.challenge as ch
LEFT JOIN challenge.fischer_time_control as tc
ON ch.id = tc.challenge_id
WHERE ch.id = {challenge_id}
AND ch.challenge_type != 'direct'