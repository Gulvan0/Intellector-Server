package;

import database.endpoints.Log;
import database.QueryShortcut;
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
            Log.antifraud(database, "elo", playerLogin, delta, gameID);
    }

    public static function stringifyMessage(clientMessage:ClientMessage) 
    {
        return switch clientMessage 
        {
            case Event(id, event):
                'Event(${event.getName()}(${getClientEventArgs(event)}))';
            case Request(id, request):
                'Request(${request.getName()}(${getClientRequestArgs(request)}))';
            default:
        } 
    }

    public static function clientMessage(connectionID:String, clientMessage:ClientMessage)
    {
        if (database == null)
            return;

        switch clientMessage 
        {
            case Event(id, event):
                Log.message(database, "client", connectionID, id, "event", event.getName(), getClientEventArgs(event));
            case Request(id, request):
                Log.message(database, "client", connectionID, id, "request", request.getName(), getClientRequestArgs(request));
            default:
        }
    }

    public static function serverMessage(connectionID:String, serverMessage:ServerMessage)
    {
        if (database == null)
            return;

        switch serverMessage 
        {
            case Event(id, event):
                Log.message(database, "server", connectionID, id, "event", event.getName(), getServerEventArgs(event));
            case RequestResponse(requestID, response):
                Log.message(database, "server", connectionID, requestID, "request", response.getName(), getServerRequestResponseArgs(response));
            default:
                return;
        }
    }

    public static function info(serviceSlug:Null<String>, message:String) 
    {
        if (database != null)
            Log.service(database, "info", serviceSlug, message);
        
        if (Config.config.printLog)
            Sys.println('INFO: $message');
    }

    public static function error(serviceSlug:Null<String>, message:String, ?notifyAdmin:Bool = true) 
    {
        if (database != null)
            Log.service(database, "error", serviceSlug, message);
        
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