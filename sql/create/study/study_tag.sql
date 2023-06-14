CREATE TABLE study.study_tag (
    study_id MEDIUMINT NOT NULL,
    tag VARCHAR(15) NOT NULL,

    INDEX study_id_ind (study_id),

    FOREIGN KEY (study_id) 
        REFERENCES study.study (id)
)