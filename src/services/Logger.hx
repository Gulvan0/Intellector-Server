package services;

import net.shared.ServerMessage;
import net.shared.ClientMessage;
import services.Storage.LogType;
import entities.UserSession;
import net.shared.ServerEvent;
import integration.Telegram;
import net.shared.ClientEvent;

class Logger
{
    public static function stringifyClientEvent(event:ClientEvent):String 
    {
        return switch event 
        {
            case Login(login, _): 'Login($login, ***)';
            case Register(login, _): 'Register($login, ***)';
            case Greet(Login(login, _), clientBuild, minServerBuild): 'Greet(Login($login, ***), $clientBuild, $minServerBuild)';
            case MissedEvents(map): 'MissedEvents(${[for (key in map.keys()) key].join(', ')})';
            default: '${event.getName()}(${event.getParameters().join(', ')})';
        }
    }

    public static function stringifyServerEvent(event:ServerEvent):String 
    {
        return switch event
        {
            case GreetingResponse(Reconnected(missedEvents)): 'GreetingResponse(Reconnected(${[for (key in missedEvents.keys()) key].join(', ')}))';
            case MissedEvents(map): 'MissedEvents(${[for (key in map.keys()) key].join(', ')})';
            default: '${event.getName()}(${event.getParameters().join(', ')})';
        }
    }

    public static function logIncomingMessage(message:ClientMessage, senderID:String, ?sender:Null<UserSession>) 
    {
        if (message.event.match(KeepAliveBeat))
            return;

        var userStr:String = sender != null? sender.getReference() : senderID;
        var eventStr:String = stringifyClientEvent(message.event);
        var entry:String = '$userStr | ${message.id} | $eventStr';
        appendLog(Event, entry, '>');
    }

    public static function logOutgoingMessage(message:ServerMessage, receiverID:String, ?receiver:Null<UserSession>) 
    {
        if (message.event.match(KeepAliveBeat))
            return;

        var userStr:String = receiver != null? receiver.getReference() : receiverID;
        var eventStr:String = stringifyServerEvent(message.event);
        var entry:String = '$userStr | ${message.id} | $eventStr';
        appendLog(Event, entry, '<');
    }

    public static function addAntifraudEntry(playerLogin:String, valueName:String, oldValue:Float, newValue:Float) 
    {
        var delta:Float = newValue - oldValue;
        var deltaStr:String = delta > 0? '+$delta' : '$delta';
        var entry:String = '$valueName $playerLogin: $oldValue -> $newValue ($deltaStr)';
        appendLog(Antifraud, entry, '$');
    }

    public static function logError(entry:String, ?notifyAdmin:Bool = true) 
    {
        if (notifyAdmin)
            IntegrationManager.notifyAdmin(entry);
        appendLog(Error, entry, '!');
    }

    public static function serviceLog(service:String, entry:String) 
    {
        appendLog(Full, entry, '@ $service:');
    }

    private static function appendLog(log:LogType, message:String, ?prefix:String) 
    {
        var seconds:Float = Sys.time();
        var unixStr:String = Std.string(Math.floor(seconds));
        var dateStr:String = Date.fromTime(seconds * 1000).toString();
        var msRemainder:String = Std.string(seconds % 1).substr(1, 4);

        var prefixedMessage:String = prefix + ' ' + message;

        var entry:String = '|$unixStr|$dateStr$msRemainder $message\n';
        Storage.appendLog(log, entry);

        if (Config.printLog)
            Sys.println(prefixedMessage);

        if (log != Full)
        {
            var prefixedEntry:String = '|$unixStr|$dateStr$msRemainder $prefixedMessage\n';
            Storage.appendLog(Full, prefixedEntry);
        }

    }
}