package services;

import entities.UserSession;
import net.shared.ServerEvent;
import integration.Telegram;
import net.shared.ClientEvent;

class Logger
{
    public static function logIncomingEvent(event:ClientEvent, senderID:String, ?sender:Null<UserSession>) 
    {
        var userStr:String = sender != null? sender.getLogReference() : senderID;
        var eventStr:String = switch event 
        {
            case Login(login, _): 'Login($login, ***)';
            case Register(login, _): 'Register($login, ***)';
            case Greet(Login(login, _)): 'Greet(Login($login, ***))';
            default: '${event.getName()}(${event.getParameters().join(', ')})';
        }
        
        var message:String = '> $userStr | $eventStr';
        Storage.appendLog(Event, message);
        Storage.appendLog(Full, message);
        if (Config.printLog)
            Sys.println(message);
    }

    public static function logOutgoingEvent(event:ServerEvent, receiverID:String, ?receiver:Null<UserSession>) 
    {
        var userStr:String = receiver != null? receiver.getLogReference() : receiverID;
        var eventStr:String = '${event.getName()}(${event.getParameters().join(', ')})';

        var message:String = '< $userStr | $eventStr';
        Storage.appendLog(Event, message);
        Storage.appendLog(Full, message);
        if (Config.printLog)
            Sys.println(message);
    }

    public static function addAntifraudEntry(playerLogin:String, valueName:String, oldValue:Float, newValue:Float) 
    {
        var message:String = '$valueName $playerLogin: $oldValue -> $newValue (${newValue - oldValue})';
        Storage.appendLog(Antifraud, message);
        Storage.appendLog(Full, "$ " + message);
        if (Config.printLog)
            Sys.println("$ " + message);
    }

    public static function logError(message:String, ?notifyAdmin:Bool = true) 
    {
        if (notifyAdmin)
            Telegram.notifyAdmin(message);
        Storage.appendLog(Error, message);
        Storage.appendLog(Full, "! " + message);
        if (Config.printLog)
            Sys.println("! " + message);
    }

    public static function serviceLog(service:String, entry:String) 
    {
        var message:String = '@ $service | $entry';
        Storage.appendLog(Full, message);
        if (Config.printLog)
            Sys.println(message);
    }
}