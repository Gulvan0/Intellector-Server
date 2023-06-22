CREATE TABLE game.offer_event (
    event_id INT UNSIGNED NOT NULL,
    offer_action ENUM('create', 'cancel', 'accept', 'decline') NOT NULL,
    offer_kind ENUM('draw', 'takeback') NOT NULL,
    sent_by ENUM('white', 'black') NOT NULL,

    INDEX event_id_ind (event_id),

    PRIMARY KEY (event_id),

    FOREIGN KEY (event_id) 
        REFERENCES game.event (id)
)