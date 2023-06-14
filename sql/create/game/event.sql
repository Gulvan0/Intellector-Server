CREATE TABLE game.event (
    id INT NOT NULL AUTO_INCREMENT,
    game_id MEDIUMINT NOT NULL,
    ts TIMESTAMP NOT NULL,

    INDEX game_id_ind (game_id),

    PRIMARY KEY (id),

    FOREIGN KEY (game_id) 
        REFERENCES game.game (id)
)