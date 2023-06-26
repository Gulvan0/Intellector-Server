INSERT INTO challenge.challenge
SELECT
    NULL as id,
    {owner_ref} as owner_ref,
    {challenge_type} as challenge_type,
    {callee_ref} as callee_ref,
    {time_control_type} as time_control_type,
    {accepting_side_color} as accepting_side_color,
    {custom_starting_sip} as custom_starting_sip,
    {rated} as rated,
    1 as active,
    NULL as resulting_game_id;

INSERT INTO challenge.fischer_time_control
SELECT
    {LAST_INSERT_ID} as challenge_id,
    {start_secs} as start_secs,
    {increment_secs} as increment_secs