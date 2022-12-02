package entities;

import net.shared.Outcome;
import net.GameAction;
import entities.util.GameTime;
import entities.util.GameOffers;
import entities.util.GameState;
import entities.util.GameSessions;
import entities.util.GameLog;
import net.shared.dataobj.TimeReservesData;
import net.shared.PieceType;
import haxe.Timer;
import net.shared.PieceColor;
import net.shared.ServerEvent;
import net.shared.board.Situation;
import struct.TimeControl;
import services.Storage;

using StringTools;

class FiniteTimeGame extends Game 
{
    private function onTimeout(timedOutColor:PieceColor) 
    {
        endGame(Decisive(Timeout, opposite(timedOutColor)));
    }

    public function new(id:Int, players:Map<PieceColor, UserSession>, timeControl:TimeControl, rated:Bool, ?customStartingSituation:Situation)
    {
        super(id);

        log = GameLog.createNew(id, players, timeControl, rated, customStartingSituation);
        offers = new GameOffers(endGame.bind(Drawish(DrawAgreement)), rollback);
        sessions = new GameSessions(players);
        state = GameState.createNew(customStartingSituation);
        time = GameTime.active(timeControl, onTimeout);
    }
}