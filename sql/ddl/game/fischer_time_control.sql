CREATE TABLE game.fischer_time_control (
    game_id MEDIUMINT UNSIGNED NOT NULL,
    start_secs SMALLINT UNSIGNED NOT NULL,
    increment_secs SMALLINT UNSIGNED NOT NULL,

    INDEX game_id_ind (game_id),

    PRIMARY KEY (game_id),

    FOREIGN KEY (game_id) 
        REFERENCES game.game (id)
)