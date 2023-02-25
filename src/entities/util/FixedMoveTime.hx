package entities.util;

import net.shared.Constants;
import haxe.Timer;
import services.Logger;
import net.shared.dataobj.TimeReservesData;
import net.shared.PieceColor;

class FixedMoveTime implements IGameTime
{
	public final faithful:Bool;
    private final secsPerMove:Int;

    private var prevPlayerSecsLeftWhenMoved:Null<Float>;
    private var timeReservesAtMoveStart:TimeReservesData;
    private var gameEndedReserves:Null<TimeReservesData>;
    private var turnColor:PieceColor;
    private var timeoutTimer:Null<Timer>;

    private var onTimeout:PieceColor->Void;

    private function checkTime(turnColor:PieceColor, moveNum:Int) 
    {
        var timeMap = getTime(turnColor, moveNum).secsLeftMap();
        var movingPlayerSecsLeft = timeMap[turnColor];

        if (movingPlayerSecsLeft <= 0)
            onTimeout(turnColor);
        else if (timeMap[opposite(turnColor)] <= 0)
            onTimeout(opposite(turnColor));
        else if (moveNum >= 2)
            timeoutTimer = Timer.delay(checkTime.bind(turnColor, moveNum), Math.ceil(movingPlayerSecsLeft * 1000));
    }

    private function restartTimer(turnColor:PieceColor, moveNum:Int, playerMsLeft:Float) 
    {
        if (timeoutTimer != null)
            timeoutTimer.stop();

        if (moveNum >= 2 && !faithful)
            timeoutTimer = Timer.delay(checkTime.bind(turnColor, moveNum), Math.ceil(playerMsLeft));
    }

	public function setTimeDirectly(timeData:TimeReservesData) 
    {
        if (faithful)
            this.timeReservesAtMoveStart = timeData;
        else
            Logger.logError('Attempted to set time directly for non-faithful game time');
    }

	public function stopTime(turnColor:PieceColor, moveNum:Int) 
    {
        if (timeoutTimer != null)
            timeoutTimer.stop();

        this.gameEndedReserves = getTime(turnColor, moveNum);
        this.turnColor = turnColor;
    }

	public function addTime(color:PieceColor, turnColor:PieceColor, moveNum:Int) 
    {
        timeReservesAtMoveStart.addSecsLeftAtTimestamp(color, Constants.msAddedByOpponent / 1000);
        if (color == turnColor)
            restartTimer(turnColor, moveNum, getTime(turnColor, moveNum).secsLeftMap()[turnColor] * 1000);
    }

	public function onMoveMade(movedPlayerColor:PieceColor, moveNum:Int) 
    {
        var timeData:TimeReservesData = getTime(turnColor, moveNum);
        prevPlayerSecsLeftWhenMoved = timeData.getSecsLeftAtTimestamp(turnColor);

        if (faithful || prevPlayerSecsLeftWhenMoved > 0)
        {
            timeReservesAtMoveStart = timeData;
            timeReservesAtMoveStart.setSecsLeftAtTimestamp(turnColor, secsPerMove);

            restartTimer(opposite(turnColor), moveNum + 1, timeReservesAtMoveStart.getSecsLeftAtTimestamp(opposite(turnColor)) * 1000);
        }
        else
            onTimeout(turnColor);
    }

	public function onRollback(moveCnt:Int, newTurnColor:PieceColor, newMoveNum:Int) 
    {
        this.turnColor = newTurnColor;
        this.prevPlayerSecsLeftWhenMoved = null;
        this.timeReservesAtMoveStart = new TimeReservesData(secsPerMove, secsPerMove, Sys.time() * 1000);
        restartTimer(newTurnColor, newMoveNum, secsPerMove * 1000);
    }

	public function getTime(turnColor:PieceColor, moveNum:Int):Null<TimeReservesData> 
    {
        if (gameEndedReserves != null)
        {
            gameEndedReserves.timestamp = Sys.time() * 1000;
            return gameEndedReserves;
        }

        var timestamp:Float = Sys.time() * 1000;
        var msPassed:Float = moveNum < 2? 0 : timestamp - timeReservesAtMoveStart.timestamp;

        var secsLeft:Map<PieceColor, Float> = timeReservesAtMoveStart.secsLeftMap();
        secsLeft[turnColor] -= msPassed / 1000;

        var secsLeftWhite:Float = Math.max(secsLeft[White], 0);
        var secsLeftBlack:Float = Math.max(secsLeft[Black], 0);

        return new TimeReservesData(secsLeftWhite, secsLeftBlack, timestamp);
    }

	public function getLoggedMsAfterPrevMove():Null<Map<PieceColor, Int>> 
    {
        if (prevPlayerSecsLeftWhenMoved != null)
        {
            var map:Map<PieceColor, Int> = [];
            map.set(turnColor, Math.round(timeReservesAtMoveStart.getSecsLeftAtTimestamp(turnColor) * 1000));
            map.set(opposite(turnColor), Math.round(prevPlayerSecsLeftWhenMoved * 1000));
            return map;
        }
        else
            return null;
    }

    public function new(faithful:Bool, secsPerMove:Int, onTimeout:PieceColor->Void) 
    {
        this.faithful = faithful;  
        this.secsPerMove = secsPerMove;   
        this.onTimeout = onTimeout;   
    }
}