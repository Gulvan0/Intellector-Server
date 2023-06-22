package;

import net.shared.message.ServerRequestResponse;
import net.shared.message.ClientRequest;
import net.shared.message.ClientEvent;
import net.shared.message.ServerEvent;
import net.shared.message.ClientMessage;
import config.Config;
import services.IntegrationManager;
import net.shared.message.ServerMessage;
import net.shared.message.ClientMessage;
import database.Database;

class Logging 
{
    private static var database:Database;

    private static function getClientEventArgs(event:ClientEvent):String 
    {
        return event.getParameters().join(', ').substr(0, 500);
    }

    private static function getServerEventArgs(event:ServerEvent):String 
    {
        return event.getParameters().join(', ').substr(0, 500);
    }

    private static function getClientRequestArgs(request:ClientRequest):String 
    {
        switch request 
        {
            case Login(login, _), Register(login, _):
                return '$login, ***';
            default:
                return event.getParameters().join(', ').substr(0, 500);
        }
    }

    private static function getServerRequestResponseArgs(response:ServerRequestResponse):String 
    {
        return response.getParameters().join(', ').substr(0, 500);
    }

    public static function antifraudEloUpdate(playerLogin:String, delta:Int, gameID:Int)
    {
        if (database != null)
        {
            var substitutions:Map<String, String> = [
                "entry_type" => "elo",
                "player_login" => playerLogin,
                "delta" => delta,
                "game_id" => gameID
            ];
            database.executeQuery("sql/dml/logging/append_antifraud.sql", substitutions);
        }
    }    

    public static function clientMessage(connectionID:Int, clientMessage:ClientMessage)
    {
        var substitutions:Map<String, String> = [
            "source" => "client",
            "connection_id" => connectionID
        ];

        switch clientMessage 
        {
            case Event(id, event):
                substitutions["message_id"] = id;
                substitutions["message_type"] = "event";
                substitutions["message_name"] = event.getName();
                substitutions["message_args"] = getClientEventArgs(event);
            case Request(id, request):
                substitutions["message_id"] = id;
                substitutions["message_type"] = "request";
                substitutions["message_name"] = request.getName();
                substitutions["message_args"] = getClientRequestArgs(request);
            default:
                return;
        }

        if (database != null)
            database.executeQuery("sql/dml/logging/append_message.sql", substitutions);
    }

    public static function serverMessage(connectionID:Int, serverMessage:ServerMessage)
    {
        var substitutions:Map<String, String> = [
            "source" => "server",
            "connection_id" => connectionID
        ];

        switch serverMessage 
        {
            case Event(id, event):
                substitutions["message_id"] = id;
                substitutions["message_type"] = "event";
                substitutions["message_name"] = event.getName();
                substitutions["message_args"] = getServerEventArgs(event);
            case RequestResponse(requestID, response):
                substitutions["message_id"] = requestID;
                substitutions["message_type"] = "request";
                substitutions["message_name"] = response.getName();
                substitutions["message_args"] = getServerRequestResponseArgs(response);
            default:
                return;
        }

        if (database != null)
            database.executeQuery("sql/dml/logging/append_message.sql", substitutions);
    }

    public static function info(serviceSlug:Null<String>, message:String) 
    {
        if (database != null)
        {
            var substitutions:Map<String, String> = [
                "entry_type" => "info",
                "service_slug" => serviceSlug,
                "entry_text" => message
            ];
            database.executeQuery("sql/dml/logging/append_service.sql", substitutions);
        }
        
        if (Config.config.printLog)
            Sys.println('INFO: $message');
    }

    public static function error(serviceSlug:Null<String>, message:String, ?notifyAdmin:Bool = true) 
    {
        if (database != null)
        {
            var substitutions:Map<String, String> = [
                "entry_type" => "error",
                "service_slug" => serviceSlug,
                "entry_text" => message
            ];
            database.executeQuery("sql/dml/logging/append_service.sql", substitutions);
        }
        
        if (Config.config.printLog)
            Sys.println('ERROR: $message');

        if (notifyAdmin)
            IntegrationManager.notifyAdmin(message);
    }

    public static function init(database:Database) 
    {
        Logging.database = database;
    }
}