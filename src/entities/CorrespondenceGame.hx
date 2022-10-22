package entities;

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
        
        //TODO: Fill

        return game;
    }

    public static function loadFromLog(id:Int):CorrespondenceGame 
    {
        var game:CorrespondenceGame = new CorrespondenceGame(id);

        var log:String = Storage.getGameLog(id);

        if (log == null)
            throw 'Attempted to load correspondence game $id from log, but it does not exist';

        //TODO: Fill

        return game;
    }

    private function new(id:Int) 
    {
        this.id = id;
    }    
}