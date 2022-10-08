package;

import sys.thread.Thread;
import integration.Telegram;
import haxe.Timer;
import haxe.Serializer;
import services.Auth;
import services.Logger;
import haxe.Unserializer;
import services.Storage;

class Routines
{
    public static function onStartup() 
    {
        Serializer.USE_ENUM_INDEX = true;
        
        Storage.createMissingFiles();
        Config.load();

        hx.ws.Log.mask = Config.logMask;
        Storage.repairGameLogs();
        Auth.loadPasswords();

        Thread.createWithEventLoop(initCheckTGTimer);
    }

    private static function initCheckTGTimer() 
    {
        var timer:Timer = new Timer(1000);
        timer.run = Telegram.checkAdminChat;    
    }
}