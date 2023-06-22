CREATE TABLE log.service_log (
    ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    entry_type ENUM('info','error') NOT NULL,
    service_slug VARCHAR(30)
)