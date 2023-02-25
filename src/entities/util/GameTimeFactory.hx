package entities.util;

import net.shared.PieceColor;
import net.shared.TimeControl;

class GameTimeFactory 
{
    public static function build(timeControl:TimeControl, faithful:Bool, onTimeout:PieceColor->Void):IGameTime
    {
        switch timeControl 
        {
            case Correspondence:
                return new NilTime();
            case Fischer(startSecs, incrementSecs):
                return new FischerGameTime(faithful, startSecs, incrementSecs, onTimeout);
            case FixedTimePerMove(secsPerMove):
                return new FixedMoveTime(faithful, secsPerMove, onTimeout);
        }
    }    
}