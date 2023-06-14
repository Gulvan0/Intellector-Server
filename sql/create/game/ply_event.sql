CREATE TABLE game.ply_event (
    event_id INT NOT NULL,
    departure_coord TINYINT NOT NULL,
    destination_coord TINYINT NOT NULL,
    morph_into ENUM('aggressor','defensor','dominator','liberator','progressor'),

    INDEX event_id_ind (event_id),

    PRIMARY KEY (event_id),

    FOREIGN KEY (event_id) 
        REFERENCES game.event (id)
)