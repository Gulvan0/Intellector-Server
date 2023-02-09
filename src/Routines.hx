package;

import services.LogReader;
import services.IntegrationManager;
import services.CommandProcessor;
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

        IntegrationManager.init();
        LogReader.init();
        
        Storage.createMissingFiles();
        Config.load();

        hx.ws.Log.mask = Config.logMask;
        Storage.repairGameLogs();
        Auth.loadPasswords();
        Telegram.init();

        initTimer(1000, Telegram.checkAdminChat, 'checkAdminTG');
        Thread.createWithEventLoop(watchStdin);

        Telegram.notifyAdmin("Server started");
    }

    private static function watchStdin() 
    {
        while (true)
            CommandProcessor.processCommand(Sys.stdin().readLine(), Sys.println);
    }

    private static function initTimer(intervalMs:Int, callback:Void->Void, routineName:String) 
    {
        var timer:Timer = new Timer(intervalMs);
        timer.run = () -> 
        {
            try
            {
                Thread.createWithEventLoop(callback);
            }
            catch (e)
            {
                Logger.logError('Routine error ($routineName)\nException:\n${e.message}\nNative:\n${e.native}\nPrevious:\n${e.previous}\nStack:\n${e.stack}');
            }
        }  
    }
}