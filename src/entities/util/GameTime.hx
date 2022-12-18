package entities.util;

import net.shared.Constants;
import struct.TimeControl;
import net.shared.dataobj.TimeReservesData;
import haxe.Timer;
import net.shared.PieceColor;

using utils.ds.ArrayTools;

interface IGameTime 
{
    public function stopTime(turnColor:PieceColor, moveNum:Int):Void;
    public function addTime(color:PieceColor, turnColor:PieceColor, moveNum:Int):Void;
    public function onMoveMade(movedPlayerColor:PieceColor, moveNum:Int):Void;
    public function onRollback(moveCnt:Int, newTurnColor:PieceColor, newMoveNum:Int):Void;
    public function getTime(turnColor:PieceColor, moveNum:Int):Null<TimeReservesData>;
    public function getMsAtMoveStart():Null<Map<PieceColor, Int>>;
}

private class Nil implements IGameTime
{
    public function onMoveMade(movedPlayerColor:PieceColor, moveNum:Int) {} 
    public function onRollback(moveCnt:Int, newTurnColor:PieceColor, newMoveNum:Int) {} 
    public function stopTime(turnColor:PieceColor, moveNum:Int) {} 
    public function addTime(color:PieceColor, turnColor:PieceColor, moveNum:Int) {}

    public function getTime(turnColor:PieceColor, moveNum:Int):Null<TimeReservesData> 
    {
        return null;
    } 

    public function getMsAtMoveStart():Null<Map<PieceColor, Int>>
    {
        return null;
    }

    public function new() 
    {
        
    }
}

class GameTime implements IGameTime
{
    private var timeControl:TimeControl;
    private var secondsLeftOnMoveStart:Array<Map<PieceColor, Float>> = [];
    private var moveStartTimestamp:Float;

    private var finalTimeLeft:Null<TimeReservesData> = null;

    private var timeoutTerminationTimer:Null<Timer> = null;
    
    private var onTimeout:PieceColor->Void;

    public function getMsAtMoveStart():Null<Map<PieceColor, Int>>
    {
        var timeMap = secondsLeftOnMoveStart.last();
        return [White => Math.round(timeMap[White] * 1000), Black => Math.round(timeMap[Black] * 1000)];
    }

    public function onMoveMade(turnColor:PieceColor, moveNum:Int) 
    {
        var timeData:TimeReservesData = getTime(turnColor, moveNum);
        var timeMap = timeData.secsLeftMap();

        if (timeMap[turnColor] > 0)
        {
            if (moveNum >= 2)
                timeMap[turnColor] += timeControl.incrementSecs;
            secondsLeftOnMoveStart.push(timeMap);
            moveStartTimestamp = timeData.timestamp;

            restartTimer(opposite(turnColor), moveNum + 1, timeMap[opposite(turnColor)] * 1000);
        }
        else
            onTimeout(turnColor);
    }

    private function stopTimer() 
    {
        if (timeoutTerminationTimer != null)
            timeoutTerminationTimer.stop();
    }

    private function restartTimer(turnColor:PieceColor, moveNum:Int, playerMsLeft:Float) 
    {
        stopTimer();
        if (moveNum >= 2)
            timeoutTerminationTimer = Timer.delay(checkTime.bind(turnColor, moveNum), Math.ceil(playerMsLeft));
    }

    public function onRollback(moveCnt:Int, newTurnColor:PieceColor, newMoveNum:Int) 
    {
        secondsLeftOnMoveStart = secondsLeftOnMoveStart.slice(0, -moveCnt);
        moveStartTimestamp = Sys.time() * 1000;
        restartTimer(newTurnColor, newMoveNum, getMsAtMoveStart()[newTurnColor]);
    }

    public function getTime(turnColor:PieceColor, moveNum:Int):Null<TimeReservesData> 
    {
        if (finalTimeLeft != null)
        {
            finalTimeLeft.timestamp = Sys.time() * 1000;
            return finalTimeLeft;
        }

        var timestamp:Float = Sys.time() * 1000;
        var msPassed:Float = moveNum < 2? 0 : timestamp - moveStartTimestamp;

        var secsLeft:Map<PieceColor, Float> = secondsLeftOnMoveStart.last().copy();
        secsLeft[turnColor] -= msPassed / 1000;

        var secsLeftWhite:Float = Math.max(secsLeft[White], 0);
        var secsLeftBlack:Float = Math.max(secsLeft[Black], 0);

        return new TimeReservesData(secsLeftWhite, secsLeftBlack, timestamp);
    } 

    private function checkTime(turnColor:PieceColor, moveNum:Int) 
    {
        var timeMap = getTime(turnColor, moveNum).secsLeftMap();
        var movingPlayerSecsLeft = timeMap[turnColor];

        if (movingPlayerSecsLeft <= 0)
            onTimeout(turnColor);
        else if (timeMap[opposite(turnColor)] <= 0)
            onTimeout(opposite(turnColor));
        else if (moveNum >= 2)
            timeoutTerminationTimer = Timer.delay(checkTime.bind(turnColor, moveNum), Math.ceil(movingPlayerSecsLeft * 1000));
    }

    public function stopTime(turnColor:PieceColor, moveNum:Int) 
    {
        finalTimeLeft = getTime(turnColor, moveNum);
        stopTimer();
    }

    public function addTime(color:PieceColor, turnColor:PieceColor, moveNum:Int) 
    {
        secondsLeftOnMoveStart.last()[color] += Constants.msAddedByOpponent / 1000;
        if (color == turnColor)
            restartTimer(turnColor, moveNum, getTime(turnColor, moveNum).secsLeftMap()[turnColor] * 1000);
    }

    public static function nil():IGameTime
    {
        return new Nil();
    }

    public static function active(timeControl:TimeControl, onTimeout:PieceColor->Void):IGameTime
    {
        return new GameTime(timeControl, onTimeout);
    }

    private function new(timeControl:TimeControl, onTimeout:PieceColor->Void) 
    {
        this.onTimeout = onTimeout;
        this.timeControl = timeControl;
        secondsLeftOnMoveStart.push([White => timeControl.startSecs, Black => timeControl.startSecs]);
        moveStartTimestamp = Sys.time() * 1000;
    }
}