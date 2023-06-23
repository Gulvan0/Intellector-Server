INSERT INTO challenge.challenge
SELECT
    NULL as id,
    {owner_ref} as owner_ref,
    {challenge_type} as challenge_type,
    {callee_ref} as callee_ref,
    {accepting_side_color} as accepting_side_color,
    {custom_starting_sip} as custom_starting_sip,
    {rated} as rated,
    1 as active,
    NULL as resulting_game_id