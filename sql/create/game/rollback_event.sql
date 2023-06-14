CREATE TABLE game.rollback_event (
    event_id INT NOT NULL,
    cancelled_moves_cnt TINYINT NOT NULL,

    INDEX event_id_ind (event_id),

    PRIMARY KEY (event_id),

    FOREIGN KEY (event_id) 
        REFERENCES game.event (id)
)