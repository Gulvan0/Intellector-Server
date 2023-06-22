CREATE TABLE connection.viewed_study_event (
    ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    connection_id MEDIUMINT UNSIGNED NOT NULL,
    study_id MEDIUMINT UNSIGNED,

    INDEX study_id_ind (study_id),

    FOREIGN KEY (study_id) 
        REFERENCES study.study (id)
)