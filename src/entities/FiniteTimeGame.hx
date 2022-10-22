package entities;

import net.shared.TimeReservesData;
import net.shared.PieceType;
import haxe.Timer;
import net.shared.PieceColor;
import net.shared.ServerEvent;
import struct.Situation;
import struct.Ply;
import struct.TimeControl;
import services.Storage;

using StringTools;

class FiniteTimeGame extends Game 
{
    private var secondsLeftOnMoveStart:Array<Map<PieceColor, Float>> = [];
    private var moveStartTimestamp:Float;

    private var timeoutTerminationTimer:Null<Timer> = null;
    
    //TODO: Fill

    public function new(id:Int, whitePlayer:UserSession, blackPlayer:UserSession, timeControl:TimeControl, ?customStartingSituation:Situation)
    {
        //TODO: Fill
    }
}