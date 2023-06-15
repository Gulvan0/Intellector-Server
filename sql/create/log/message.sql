CREATE TABLE log.message (
    ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    source ENUM('client','server') NOT NULL,
    connection_id MEDIUMINT UNSIGNED NOT NULL,
    message_id SMALLINT UNSIGNED NOT NULL,
    event_name VARCHAR(50) NOT NULL,
    event_args VARCHAR(500)
)