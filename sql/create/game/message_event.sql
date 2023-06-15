CREATE TABLE game.message_event (
    event_id INT UNSIGNED NOT NULL,
    author_ref VARCHAR(16) NOT NULL,
    msg_text VARCHAR(500) NOT NULL,

    INDEX event_id_ind (event_id),

    PRIMARY KEY (event_id),

    FOREIGN KEY (event_id) 
        REFERENCES game.event (id)
)