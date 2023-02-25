package entities.util;

import net.shared.dataobj.TimeReservesData;
import net.shared.PieceColor;

interface IGameTime 
{
    public final faithful:Bool;

    public function setTimeDirectly(timeData:TimeReservesData):Void;
    public function stopTime(turnColor:PieceColor, moveNum:Int):Void;
    public function addTime(color:PieceColor, turnColor:PieceColor, moveNum:Int):Void;
    public function onMoveMade(movedPlayerColor:PieceColor, moveNum:Int):Void;
    public function onRollback(moveCnt:Int, newTurnColor:PieceColor, newMoveNum:Int):Void;
    public function getTime(turnColor:PieceColor, moveNum:Int):Null<TimeReservesData>;
    public function getLoggedMsAfterPrevMove():Null<Map<PieceColor, Int>>;
}