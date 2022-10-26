package utils;

import haxe.Timer;

class MovingCountdownTimer 
{
    private var callback:Void->Void;
    private var delayMs:Int;

    private var timer:Timer;
    
    public function stop() 
    {
        timer.stop();    
    }

    public function refresh(?newDelayMs:Null<Int>) 
    {
        timer.stop();

        if (newDelayMs != null)
            delayMs = newDelayMs;

        timer = Timer.delay(callback, delayMs);
    }

    public function new(callback:Void->Void, delayMs:Int) 
    {
        this.callback = callback;
        this.delayMs = delayMs;

        this.timer = Timer.delay(callback, delayMs);
    }
}