CREATE TABLE connection.viewed_profile_event (
    ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    connection_id MEDIUMINT UNSIGNED NOT NULL,
    profile_owner_login VARCHAR(16) NOT NULL,

    INDEX profile_owner_login_ind (profile_owner_login),

    FOREIGN KEY (profile_owner_login) 
        REFERENCES player.player (player_login)
)