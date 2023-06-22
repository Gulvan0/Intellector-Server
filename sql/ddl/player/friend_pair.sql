CREATE TABLE player.friend_pair (
    friend_owner_login VARCHAR(16) NOT NULL,
    friend_login VARCHAR(16) NOT NULL,

    INDEX friend_owner_login_ind (friend_owner_login),
    INDEX friend_login_ind (friend_login),

    FOREIGN KEY (friend_owner_login) 
        REFERENCES player.player (player_login),
    FOREIGN KEY (friend_login) 
        REFERENCES player.player (player_login)
)