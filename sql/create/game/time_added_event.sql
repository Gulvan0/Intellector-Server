CREATE TABLE game.time_added_event (
    event_id INT NOT NULL,
    receiving_color ENUM('white', 'black') NOT NULL,

    INDEX event_id_ind (event_id),

    PRIMARY KEY (event_id),

    FOREIGN KEY (event_id) 
        REFERENCES game.event (id)
)