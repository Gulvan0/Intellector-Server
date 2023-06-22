CREATE TABLE player.player (
    player_login VARCHAR(16) NOT NULL,
    password_hash CHAR(32) NOT NULL,

    PRIMARY KEY (player_login)
)