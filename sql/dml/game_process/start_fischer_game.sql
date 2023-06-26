INSERT INTO game.game
SELECT
    NULL as id,
    {white_player_ref} as white_player_ref,
    {black_player_ref} as black_player_ref,
    {time_control_type} as time_control_type,
    {rated} as rated,
    CURRENT_TIMESTAMP as start_ts,
    {custom_starting_sip} as custom_starting_sip;

INSERT INTO game.fischer_time_control
SELECT
    {LAST_INSERT_ID} as game_id,
    {start_secs} as start_secs,
    {increment_secs} as increment_secs