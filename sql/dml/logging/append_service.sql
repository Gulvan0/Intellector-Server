INSERT INTO log.service
SELECT
    NULL as ts,
    {entry_type} as entry_type,
    {service_slug} as service_slug,
    {entry_text} as entry_text