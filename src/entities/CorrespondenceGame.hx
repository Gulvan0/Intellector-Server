package entities;

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
    public static function createNew(id:Int, onEndedCallback:Outcome->Game->Void, whitePlayer:Null<UserSession>, blackPlayer:Null<UserSession>, ?customStartingSituation:Situation):CorrespondenceGame
    {
        var game:CorrespondenceGame = new CorrespondenceGame(id, onEndedCallback);
        
        game.log = GameLog.createNew(id, whitePlayer, blackPlayer, new TimeControl(0, 0), customStartingSituation);
        game.offers = new GameOffers(game.endGame.bind(Drawish(DrawAgreement)), game.rollback);
        game.sessions = new GameSessions(false, whitePlayer, blackPlayer);
        game.state = GameState.createNew(customStartingSituation);

        return game;
    }

    public static function loadFromLog(id:Int, onEndedCallback:Outcome->Game->Void, activeSpectators:Array<UserSession>):Null<CorrespondenceGame> 
    {
        if (!Storage.exists(GameData(id)))
            return null;

        var game:CorrespondenceGame = new CorrespondenceGame(id, onEndedCallback);

        game.log = GameLog.load(id);

        if (!game.log.ongoing || !game.log.timeControl.isCorrespondence())
            return null;

        game.offers = GameOffers.createFromLog(game.log.getEntries(), game.endGame.bind(Drawish(DrawAgreement)), game.rollback);
        game.sessions = new GameSessions(false, null, null, activeSpectators);
        game.state = GameState.createFromLog(game.log.getEntries());

        return game;
    }

    private function new(id:Int, onEndedCallback:Outcome->Game->Void) 
    {
        super(id, onEndedCallback);

        this.time = GameTime.nil();
    }
}