CREATE TABLE player.ranked_progress (
    player_login VARCHAR(16) NOT NULL,
    time_control_type ENUM('hyperbullet', 'bullet', 'blitz', 'rapid', 'classic', 'correspondence') NOT NULL,
    ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    elo SMALLINT UNSIGNED NOT NULL,
    ranked_games_played SMALLINT UNSIGNED NOT NULL,

    INDEX player_login_ind (player_login),

    PRIMARY KEY (player_login, time_control_type),

    FOREIGN KEY (player_login) 
        REFERENCES player.player (player_login)
)