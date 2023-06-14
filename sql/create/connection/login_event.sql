CREATE TABLE connection.login_event (
    ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    session_id MEDIUMINT NOT NULL,
    assigned_ref VARCHAR(16),

    INDEX session_id_ind (session_id),

    FOREIGN KEY (session_id) 
        REFERENCES connection.session_token (session_id)
)