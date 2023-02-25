package entities.util;

import services.Logger;
import net.shared.TimeControl;
import net.shared.Constants;
import net.shared.dataobj.TimeReservesData;
import haxe.Timer;
import net.shared.PieceColor;

using utils.ds.ArrayTools;

class FischerGameTime implements IGameTime
{
	public final faithful:Bool;
    private var secsPerMove:Int;
    private var secondsLeftOnMoveStart:Array<Map<PieceColor, Float>> = [];
    private var moveStartTimestamp:Float;

    private var finalTimeLeft:Null<TimeReservesData> = null;

    private var timeoutTerminationTimer:Null<Timer> = null;
    
    private var onTimeout:PieceColor->Void;

    public function setTimeDirectly(timeData:TimeReservesData) 
    {
        if (faithful)
        {

        }
        else
            Logger.logError('Attempted to set time directly for non-faithful game time');
    }

    public function getLoggedMsAfterPrevMove():Null<Map<PieceColor, Int>>
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
                timeMap[turnColor] += secsPerMove;
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

    public function new(faithful:Bool, startSecs:Int, secsPerMove:Int, onTimeout:PieceColor->Void) 
    {
        this.faithful = faithful;
        this.onTimeout = onTimeout;
        this.secsPerMove = secsPerMove;
        this.secondsLeftOnMoveStart.push([White => startSecs, Black => startSecs]);
        this.moveStartTimestamp = Sys.time() * 1000;
    }
}