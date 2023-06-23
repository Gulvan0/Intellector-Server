SELECT
    ch.id as id,
    ch.owner_ref as owner_ref,
    ch.accepting_side_color as accepting_side_color,
    ch.custom_starting_sip as custom_starting_sip,
    ch.rated as rated,
    tc.start_secs as start_secs,
    tc.increment_secs as increment_secs
FROM challenge.challenge as ch
LEFT JOIN challenge.fischer_time_control as tc
ON ch.id = tc.challenge_id
WHERE ch.active = 1
AND ch.challenge_type = 'public'