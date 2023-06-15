CREATE TABLE log.antifraud (
    ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    entry_type ENUM('elo','xp') NOT NULL,
    player_login VARCHAR(16) NOT NULL,
    delta SMALLINT NOT NULL,
    game_id MEDIUMINT UNSIGNED,

    INDEX player_login_ind (player_login),
    INDEX game_id_ind (game_id),

    FOREIGN KEY (player_login) 
        REFERENCES player.player (player_login)
    FOREIGN KEY (game_id) 
        REFERENCES game.game (id)
)