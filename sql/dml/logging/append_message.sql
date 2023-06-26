INSERT INTO log.message
SELECT
    CURRENT_TIMESTAMP as ts,
    {source} as source,
    {connection_id} as connection_id,
    {message_id} as message_id,
    {message_type} as message_type,
    {message_name} as message_name,
    {message_args} as message_args