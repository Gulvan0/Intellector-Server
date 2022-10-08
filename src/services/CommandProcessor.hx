package services;

import services.Storage.LogType;
import entities.UserSession;

class CommandProcessor 
{ 
    public static function processCommand(rawText:String, callback:String->Void) 
    {
        var parts = rawText.split(' ');
        var command = parts[0];
        var args = parts.slice(1);

        try 
        {
            switch command 
            {
                case "get_logged":
                    var users:Array<UserSession> = LoginManager.getLoggedUsers();
                    callback(users.map(x -> x.login).toString());
                case "read_log":
                    if (args.length > 0)
                    {
                        var logText:String = Storage.read(Log(LogType.createByName(args[0])));
                        var readFrom:Int = args.length > 1 && Std.parseInt(args[1]) != null? -Std.parseInt(args[1]) : -100;
                        var readTo:Null<Int> = args.length > 2? -Std.parseInt(args[2]) : null;

                        var lines:Array<String> = logText.split('\n');
                        var tail:String = lines.slice(readFrom, readTo).join('\n');
                        callback(tail);
                    }
                default:
                    callback("Malformed command");
            }
        }
        catch (e)
        {
            trace(e.details());
            callback(e.details());
        }
    }
}