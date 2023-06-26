INSERT INTO game.game
SELECT
    NULL as id,
    {white_player_ref} as white_player_ref,
    {black_player_ref} as black_player_ref,
    'correspondence' as time_control_type,
    {rated} as rated,
    CURRENT_TIMESTAMP as start_ts,
    {custom_starting_sip} as custom_starting_sip