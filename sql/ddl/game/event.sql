CREATE TABLE game.event (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    game_id MEDIUMINT UNSIGNED NOT NULL,
    ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    INDEX game_id_ind (game_id),

    PRIMARY KEY (id),

    FOREIGN KEY (game_id) 
        REFERENCES game.game (id)
)