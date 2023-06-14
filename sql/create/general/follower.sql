CREATE TABLE general.follower (
    follower_session_id MEDIUMINT NOT NULL,
    followed_login VARCHAR(16) NOT NULL,

    INDEX follower_session_id_ind (follower_session_id),
    INDEX followed_login_ind (followed_login),

    PRIMARY KEY (follower_session_id),

    FOREIGN KEY (follower_session_id) 
        REFERENCES connection.session_token (session_id),
    FOREIGN KEY (followed_login) 
        REFERENCES player.player (player_login)
)