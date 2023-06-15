CREATE TABLE connection.viewed_study_event (
    ts TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    connection_id MEDIUMINT UNSIGNED NOT NULL,
    page_slug ENUM('main_menu', 'analysis', 'other', 'game', 'study', 'profile') NOT NULL
)