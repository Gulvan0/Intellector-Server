package database.endpoints;

import database.special_values.Timestamp;

class Log 
{
    public static function antifraud(entryType:String, playerLogin:String, delta:Int, gameID:Int) 
    {
        var row:Array<Dynamic> = [
            CurrentTimestamp,
            entryType,
            playerLogin,
            delta,
            gameID
        ];

        Database.instance.insertRow("log.antifraud", row, false);
    }

    public static function message(source:String, connectionID:String, messageID:Int, messageType:String, messageName:String, messageArgs:String) 
    {
        var row:Array<Dynamic> = [
            CurrentTimestamp,
            source,
            connectionID,
            messageID,
            messageType,
            messageName,
            messageArgs
        ];

        Database.instance.insertRow("log.message", row, false);
    }

    public static function service(entryType:String, serviceSlug:String, entryText:String) 
    {
        var row:Array<Dynamic> = [
            CurrentTimestamp,
            entryType,
            serviceSlug?.substr(0, 30),
            entryText
        ];

        Database.instance.insertRow("log.service", row, false);
    }    
}