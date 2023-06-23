CREATE TABLE general.server_settings (
    setting_name VARCHAR(50) NOT NULL,
    setting_value VARCHAR(500),

    PRIMARY KEY (setting_name)
)