package entities.util;

import net.shared.dataobj.TimeReservesData;
import net.shared.PieceColor;

class NilTime implements IGameTime
{
    public final faithful:Bool;

    public function setTimeDirectly(timeData:TimeReservesData) {}
    public function onMoveMade(movedPlayerColor:PieceColor, moveNum:Int) {} 
    public function onRollback(moveCnt:Int, newTurnColor:PieceColor, newMoveNum:Int) {} 
    public function stopTime(turnColor:PieceColor, moveNum:Int) {} 
    public function addTime(color:PieceColor, turnColor:PieceColor, moveNum:Int) {}

    public function getTime(turnColor:PieceColor, moveNum:Int):Null<TimeReservesData> 
    {
        return null;
    } 

    public function getLoggedMsAfterPrevMove():Null<Map<PieceColor, Int>>
    {
        return null;
    }

    public function new() 
    {
        this.faithful = true;
    }
}