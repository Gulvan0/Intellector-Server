CREATE TABLE player.elo_ban (
    player_login VARCHAR(16) NOT NULL,
    banned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    banned_until TIMESTAMP NOT NULL,

    INDEX player_login_ind (player_login),

    PRIMARY KEY (player_login, banned_at),

    FOREIGN KEY (player_login) 
        REFERENCES player.player (player_login)
)