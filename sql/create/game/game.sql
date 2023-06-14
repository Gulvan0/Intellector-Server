CREATE TABLE game.game (
    id MEDIUMINT NOT NULL AUTO_INCREMENT,
    white_player_ref VARCHAR(16) NOT NULL,
    black_player_ref VARCHAR(16) NOT NULL,
    time_control_type ENUM('hyperbullet', 'bullet', 'blitz', 'rapid', 'classic', 'correspondence') NOT NULL,
    rated BIT(1) NOT NULL,
    start_ts TIMESTAMP NOT NULL,
    custom_starting_sip VARCHAR(50),

    PRIMARY KEY (id)
)