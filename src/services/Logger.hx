package services;

import services.Storage.LogType;
import entities.UserSession;
import net.shared.ServerEvent;
import integration.Telegram;
import net.shared.ClientEvent;

class Logger
{
    public static function logIncomingEvent(event:ClientEvent, senderID:String, ?sender:Null<UserSession>) 
    {
        var userStr:String = sender != null? sender.getReference() : senderID;
        var eventStr:String = switch event 
        {
            case Login(login, _): 'Login($login, ***)';
            case Register(login, _): 'Register($login, ***)';
            case Greet(Login(login, _), clientBuild, minServerBuild): 'Greet(Login($login, ***), $clientBuild, $minServerBuild)';
            default: '${event.getName()}(${event.getParameters().join(', ')})';
        }
        
        var message:String = '$userStr | $eventStr';
        appendLog(Event, message, '>');
    }

    public static function logOutgoingEvent(event:ServerEvent, receiverID:String, ?receiver:Null<UserSession>) 
    {
        var userStr:String = receiver != null? receiver.getReference() : receiverID;
        var eventStr:String = '${event.getName()}(${event.getParameters().join(', ')})';

        var message:String = '$userStr | $eventStr';
        appendLog(Event, message, '<');
    }

    public static function addAntifraudEntry(playerLogin:String, valueName:String, oldValue:Float, newValue:Float) 
    {
        var message:String = '$valueName $playerLogin: $oldValue -> $newValue (${newValue - oldValue})';
        appendLog(Antifraud, message, '$');
    }

    public static function logError(message:String, ?notifyAdmin:Bool = true) 
    {
        if (notifyAdmin)
            IntegrationManager.notifyAdmin(message);
        appendLog(Error, message, '!');
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