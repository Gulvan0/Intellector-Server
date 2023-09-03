package;

import sources.CommandInputSource;
import sys.thread.Thread;
import haxe.Timer;

class Routines
{
    private static var commandInput:CommandInputSource = new CommandInputSource(Sys.println);
    
    public static function watchStdin() 
    {
        while (true)
            commandInput.processString(Sys.stdin().readLine());
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
                Logging.error('routine/$routineName', 'Exception:\n${e.message}\nStack:\n${e.stack}');
            }
        }  
    }
}