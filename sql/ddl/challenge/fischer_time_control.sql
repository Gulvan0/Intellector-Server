CREATE TABLE challenge.fischer_time_control (
    challenge_id MEDIUMINT UNSIGNED NOT NULL,
    start_secs SMALLINT UNSIGNED NOT NULL,
    increment_secs SMALLINT UNSIGNED NOT NULL,

    INDEX challenge_id_ind (challenge_id),

    PRIMARY KEY (challenge_id),

    FOREIGN KEY (challenge_id) 
        REFERENCES challenge.challenge (id)
)