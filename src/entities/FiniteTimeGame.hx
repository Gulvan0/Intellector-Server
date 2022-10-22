package entities;

import entities.util.GameTime;
import entities.util.GameOffers;
import entities.util.GameState;
import entities.util.GameSessions;
import entities.util.GameLog;
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
    public var time:GameTime;

    //TODO: Fill

    public function new(id:Int, whitePlayer:UserSession, blackPlayer:UserSession, timeControl:TimeControl, ?customStartingSituation:Situation)
    {
        super(id);

        log = GameLog.createNew(id, whitePlayer, blackPlayer, timeControl, customStartingSituation);
        offers = new GameOffers();
        sessions = new GameSessions(true, whitePlayer, blackPlayer);
        state = GameState.createNew(customStartingSituation);
        time = new GameTime();
    }
}