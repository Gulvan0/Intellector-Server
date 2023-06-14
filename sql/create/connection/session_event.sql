CREATE TABLE connection.session_event (
    ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    connection_id MEDIUMINT NOT NULL,
    assigned_session_id MEDIUMINT NOT NULL,

    INDEX assigned_session_id_ind (assigned_session_id),

    FOREIGN KEY (assigned_session_id) 
        REFERENCES connection.session_token (session_id)
)