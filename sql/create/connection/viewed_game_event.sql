CREATE TABLE connection.viewed_game_event (
    ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    connection_id MEDIUMINT NOT NULL,
    game_id MEDIUMINT,

    INDEX game_id_ind (game_id),

    FOREIGN KEY (game_id) 
        REFERENCES game.game (id)
)