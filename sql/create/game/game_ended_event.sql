CREATE TABLE game.game_ended_event (
    event_id INT UNSIGNED NOT NULL,
    outcome_type ENUM('mate', 'breakthrough', 'timeout', 'resign', 'abandon', 'draw_agreement', 'repetition', 'no_progress', 'abort') NOT NULL,
    winner_color ENUM('white', 'black'),

    INDEX event_id_ind (event_id),

    PRIMARY KEY (event_id),

    FOREIGN KEY (event_id) 
        REFERENCES game.event (id)
)