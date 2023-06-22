package;

import database.Database;
import config.Config;
import services.IntegrationManager;
import services.CommandProcessor;
import sys.thread.Thread;
import integration.Telegram;
import haxe.Timer;
import haxe.Serializer;
import services.Auth;
import haxe.Unserializer;

class Routines
{
    public static function watchStdin() 
    {
        while (true)
            CommandProcessor.processCommand(Sys.stdin().readLine(), Sys.println);
    }

    public static function initTimer(intervalMs:Int, callback:Void->Void, routineName:String) 
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