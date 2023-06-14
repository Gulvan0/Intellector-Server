CREATE TABLE study.study (
    id MEDIUMINT NOT NULL AUTO_INCREMENT
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    author_login VARCHAR(16) NOT NULL,
    study_name VARCHAR(25) NOT NULL,
    study_description VARCHAR(400) NOT NULL,
    publicity ENUM('public', 'direct_only', 'private') NOT NULL,
    starting_sip VARCHAR(50) NOT NULL,
    key_position_sip VARCHAR(50) NOT NULL,
    is_deleted BIT(1) NOT NULL,

    INDEX author_login_ind (author_login),

    PRIMARY KEY (id),

    FOREIGN KEY (author_login) 
        REFERENCES player.player (player_login)
)