package services;

import net.shared.ServerEvent;
import integration.Telegram;
import net.shared.ClientEvent;

class Logger
{
    public static function logIncomingEvent(event:ClientEvent, senderID:String, ?senderLogin:String) 
    {
        var senderStr:String = senderLogin == null? senderID : '$senderID ($senderLogin)';
        var eventStr:String = switch event 
        {
            case Login(login, _): 'Login($login, ***)';
            case Register(login, _): 'Register($login, ***)';
            default: '${event.getName()}(${event.getParameters().join(', ')})';
        }
        
        var message:String = '> $senderStr | $eventStr';
        Storage.appendLog(Event, message);
        Storage.appendLog(Full, message);
        if (Config.printLog)
            trace(message);
    }

    public static function logOutgoingEvent(event:ServerEvent, receiverID:String, ?receiverLogin:String) 
    {
        var receiverStr:String = receiverLogin == null? receiverID : '$receiverID ($receiverLogin)';
        var eventStr:String = '${event.getName()}(${event.getParameters().join(', ')})';

        var message:String = '< $receiverStr | $eventStr';
        Storage.appendLog(Event, message);
        Storage.appendLog(Full, message);
        if (Config.printLog)
            trace(message);
    }

    public static function logError(message:String, ?notifyAdmin:Bool = true) 
    {
        if (notifyAdmin)
            Telegram.notifyAdmin(message);
        Storage.appendLog(Error, message);
        Storage.appendLog(Full, "! " + message);
        if (Config.printLog)
            trace("! " + message);
    }

    public static function serviceLog(service:String, entry:String) 
    {
        var message:String = '@ $service | $entry';
        Storage.appendLog(Full, message);
        if (Config.printLog)
            trace(message);
    }
}