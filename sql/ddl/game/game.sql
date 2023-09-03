CREATE TABLE game.game (
    id MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
    white_player_ref VARCHAR(16) NOT NULL,
    black_player_ref VARCHAR(16) NOT NULL,
    time_control_type ENUM('hyperbullet', 'bullet', 'blitz', 'rapid', 'classic', 'correspondence') NOT NULL,
    rated BOOLEAN NOT NULL,
    start_ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    custom_starting_sip VARCHAR(50),
    most_recent_sip VARCHAR(50) NOT NULL,
    outcome_type ENUM('mate', 'breakthrough', 'timeout', 'resign', 'abandon', 'draw_agreement', 'repetition', 'no_progress', 'abort'),
    winner_color ENUM('white', 'black'),

    PRIMARY KEY (id)
)