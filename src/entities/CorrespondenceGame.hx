package entities;

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
    //TODO: Some methods

    public static function createNew(id:Int, whitePlayer:Null<UserSession>, blackPlayer:Null<UserSession>, ?customStartingSituation:Situation):CorrespondenceGame
    {
        var game:CorrespondenceGame = new CorrespondenceGame(id);
        
        game.log = GameLog.createNew(id, whitePlayer, blackPlayer, new TimeControl(0, 0), customStartingSituation);
        game.offers = new GameOffers();
        game.sessions = new GameSessions(false, whitePlayer, blackPlayer);
        game.state = GameState.createNew(customStartingSituation);

        return game;
    }

    public static function loadFromLog(id:Int):CorrespondenceGame 
    {
        var game:CorrespondenceGame = new CorrespondenceGame(id);

        var log:String = Storage.getGameLog(id);

        if (log == null)
            throw 'Attempted to load correspondence game $id from log, but it does not exist';

        game.log = GameLog.load(id);
        game.offers = GameOffers.createFromLog(game.log.getEntries());
        game.sessions = new GameSessions(false, null, null);
        game.state = GameState.createFromLog(game.log.getEntries());

        return game;
    }

    private function new(id:Int) 
    {
        super(id);
    }    
}