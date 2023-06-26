CREATE TABLE challenge.challenge (
    id MEDIUMINT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_ref VARCHAR(16) NOT NULL,
    challenge_type ENUM('public', 'link_only', 'direct') NOT NULL,
    callee_ref VARCHAR(16),
    time_control_type ENUM('hyperbullet', 'bullet', 'blitz', 'rapid', 'classic', 'correspondence') NOT NULL,
    accepting_side_color ENUM('white', 'black', 'random') NOT NULL,
    custom_starting_sip VARCHAR(50),
    rated BOOLEAN NOT NULL,
    active BOOLEAN NOT NULL,
    resulting_game_id MEDIUMINT UNSIGNED,

    INDEX resulting_game_id_ind (resulting_game_id),

    PRIMARY KEY (id),

    FOREIGN KEY (resulting_game_id) 
        REFERENCES game.game (id)
)