package database.special_values;

import net.shared.utils.UnixTimestamp;

enum Timestamp
{
    CurrentTimestamp;
    ArbitraryTimestamp(ts:UnixTimestamp);    
}