CREATE TABLE game.fischer_time_control (
    game_id MEDIUMINT NOT NULL PRIMARY KEY,
    start_secs SMALLINT NOT NULL,
    increment_secs SMALLINT NOT NULL,

    INDEX game_id_ind (game_id),

    FOREIGN KEY (game_id) 
        REFERENCES game.game (id)
)