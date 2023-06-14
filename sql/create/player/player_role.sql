CREATE TABLE player.player_role (
    player_login VARCHAR(16) NOT NULL,
    role_slug ENUM('admin', 'anaconda_developer') NOT NULL,

    INDEX player_login_ind (player_login),

    FOREIGN KEY (player_login) 
        REFERENCES player.player (player_login)
)