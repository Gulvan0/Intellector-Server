CREATE TABLE study.variation_node (
    study_id MEDIUMINT NOT NULL,
    joined_path VARCHAR(500) NOT NULL,
    ply_departure_coord TINYINT NOT NULL,
    ply_destination_coord TINYINT NOT NULL,
    ply_morph_into ENUM('aggressor','defensor','dominator','liberator','progressor'),

    INDEX study_id_ind (study_id),

    PRIMARY KEY (study_id, joined_path),

    FOREIGN KEY (study_id) 
        REFERENCES study.study (id)
)