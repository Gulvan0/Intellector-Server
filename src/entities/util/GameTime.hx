package entities.util;

import haxe.Timer;
import net.shared.PieceColor;

class GameTime 
{
    private var secondsLeftOnMoveStart:Array<Map<PieceColor, Float>> = [];
    private var moveStartTimestamp:Float;

    private var timeoutTerminationTimer:Null<Timer> = null;
    
    private var onTimeout:PieceColor->Void;

    public function onMove(movedPlayerColor:PieceColor, moveNum:Int) 
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

    public function checkTime() 
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

    public function new() 
    {
        
    }
}