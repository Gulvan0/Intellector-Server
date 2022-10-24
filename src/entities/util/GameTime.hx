package entities.util;

import net.shared.TimeReservesData;
import haxe.Timer;
import net.shared.PieceColor;

interface IGameTime 
{
    public function checkTime():Void;
    public function stopTime():Void;
    public function addTime(color:PieceColor):Void;
    public function onMoveMade(movedPlayerColor:PieceColor, moveNum:Int):Void;
    public function onRollback(moveCnt:Int):Void;
    public function onPlayerDisconnected(color:PieceColor):Void;
    public function onPlayerReconnected(color:PieceColor):Void;
    public function getTime():Null<TimeReservesData>;
}

private class Nil implements IGameTime
{
    public function onMoveMade(movedPlayerColor:PieceColor, moveNum:Int) {} 
    public function onRollback(moveCnt:Int) {} 
    public function checkTime() {} 
    public function stopTime() {} 
    public function onPlayerDisconnected(color:PieceColor) {}
    public function onPlayerReconnected(color:PieceColor) {} 
    public function addTime(color:PieceColor) {}

    public function getTime():Null<TimeReservesData> 
    {
        return null;
    } 

    public function new() 
    {
        
    }
}

class GameTime implements IGameTime
{
    private var secondsLeftOnMoveStart:Array<Map<PieceColor, Float>> = [];
    private var moveStartTimestamp:Float;

    private var timeoutTerminationTimer:Null<Timer> = null;
    
    private var onTimeout:PieceColor->Void;

    public function onMoveMade(movedPlayerColor:PieceColor, moveNum:Int) 
    {
        var msPassed:Float = moveNum <= 2? 0 : Date.now().getTime() - moveStartTimestamp;
        var secsLeft:Float = secondsLeftOnMoveStart[secondsLeftOnMoveStart.length - 1][movedPlayerColor] - msPassed * 1000;
        var secsLeftOpponent:Float = secondsLeftOnMoveStart[secondsLeftOnMoveStart.length - 1][opposite(movedPlayerColor)];

        if (secsLeft > 0)
        {
            secondsLeftOnMoveStart.push([movedPlayerColor => secsLeft, opposite(movedPlayerColor) => secsLeftOpponent]);
            moveStartTimestamp = Date.now().getTime();
        }
        else
            onTimeout(movedPlayerColor);
    }

    public function onRollback(moveCnt:Int) 
    {
        secondsLeftOnMoveStart = secondsLeftOnMoveStart.slice(0, -moveCnt);
        moveStartTimestamp = Date.now().getTime();
    }

    public function getTime():Null<TimeReservesData> 
    {
        //TODO: Fill
        return null;
    } 

    public function checkTime() 
    {
        //TODO: Fill
    }

    public function stopTime() 
    {
        //TODO: Fill
    }

    public function onPlayerDisconnected(color:PieceColor) 
    {
        //TODO: Fill
    }

    public function onPlayerReconnected(color:PieceColor) 
    {
        //TODO: Fill
    }

    public function addTime(color:PieceColor) 
    {
        //TODO: Fill
    }

    public static function nil():IGameTime
    {
        return new Nil();
    }

    public static function active(onTimeout:PieceColor->Void):IGameTime
    {
        return new GameTime(onTimeout);
    }

    private function new(onTimeout:PieceColor->Void) 
    {
        this.onTimeout = onTimeout;
    }
}