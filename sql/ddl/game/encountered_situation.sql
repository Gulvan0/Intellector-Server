CREATE TABLE game.encountered_situation (
    game_id MEDIUMINT UNSIGNED NOT NULL,
    ply_num SMALLINT UNSIGNED NOT NULL,
    sip VARCHAR(50) NOT NULL,

    INDEX game_id_ind (game_id),

    FOREIGN KEY (game_id) 
        REFERENCES game.game (id)
)