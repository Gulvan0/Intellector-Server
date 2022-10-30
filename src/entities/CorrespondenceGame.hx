package entities;

import net.shared.PieceColor;
import net.shared.Outcome;
import entities.util.GameTime;
import net.shared.TimeReservesData;
import net.GameAction;
import entities.util.GameState;
import entities.util.GameSessions;
import entities.util.GameOffers;
import struct.TimeControl;
import entities.util.GameLog;
import services.Logger;
import services.Storage;
import struct.Situation;
import net.shared.PieceType;

class CorrespondenceGame extends Game
{
    public static function createNew(id:Int, players:Map<PieceColor, UserSession>, rated:Bool, ?customStartingSituation:Situation):CorrespondenceGame
    {
        var game:CorrespondenceGame = new CorrespondenceGame(id);
        
        game.log = GameLog.createNew(id, players, TimeControl.correspondence(), rated, customStartingSituation);
        game.offers = new GameOffers(game.endGame.bind(Drawish(DrawAgreement)), game.rollback);
        game.sessions = new GameSessions(players);
        game.state = GameState.createNew(customStartingSituation);

        return game;
    }

    public static function loadFromLog(id:Int, log:GameLog):Null<CorrespondenceGame> 
    {
        if (!log.ongoing || !log.timeControl.isCorrespondence())
            return null;

        var game:CorrespondenceGame = new CorrespondenceGame(id);

        game.log = log;
        game.offers = GameOffers.createFromLog(log.getEntries(), game.endGame.bind(Drawish(DrawAgreement)), game.rollback);
        game.sessions = new GameSessions([White => null, Black => null]);
        game.state = GameState.createFromLog(log.getEntries());

        return game;
    }

    private function new(id:Int) 
    {
        super(id);

        this.time = GameTime.nil();
    }
}