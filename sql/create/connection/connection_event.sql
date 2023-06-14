CREATE TABLE connection.connection_event (
    ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    connection_id MEDIUMINT NOT NULL,
    connected BIT(1)
)