CREATE TABLE connection.session_token (
    session_id MEDIUMINT NOT NULL AUTO_INCREMENT,
    token_hash VARCHAR(32) NOT NULL,

    PRIMARY KEY (session_id)
)