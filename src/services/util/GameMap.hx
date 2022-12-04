package services.util;

import entities.Game;
import net.shared.dataobj.GameInfo;
import entities.util.GameLog;
import entities.CorrespondenceGame;
import entities.FiniteTimeGame;

class GameMap 
{
    private var finite:Map<Int, FiniteTimeGame> = [];
    private var correspondence:Map<Int, CorrespondenceGame> = [];
    
    public function getCurrentFiniteGames():Array<GameInfo>
    {
        return Lambda.map(finite, x -> x.getInfo());
    }

    public function hasCurrentFiniteGames():Bool 
    {
        return !Lambda.empty(finite);
    }

    public function get(id:Int):AnyGame 
    {
        if (finite.exists(id))
            return OngoingFinite(finite.get(id));
        else if (correspondence.exists(id))
            return OngoingCorrespondence(correspondence.get(id));

        var log:Null<GameLog> = GameLog.load(id);

        if (log == null)
            return NonExisting;
        else if (log.ongoing && log.timeControl.isCorrespondence())
        {
            var game:CorrespondenceGame = CorrespondenceGame.loadFromLog(id, log);
            correspondence.set(id, game);
            return OngoingCorrespondence(game);
        }
        else
            return Past(log.get());
    }

    public function getSimple(id:Int):SimpleAnyGame 
    {
        return switch get(id) 
        {
            case OngoingFinite(game): Ongoing(game);
            case OngoingCorrespondence(game): Ongoing(game);
            case Past(log): Past(log);
            case NonExisting: NonExisting;
        }
    }

    public function addNew(id:Int, game:Game) 
    {
        if (Std.isOfType(game, CorrespondenceGame))
            correspondence.set(id, cast(game, CorrespondenceGame));
        else
            finite.set(id, cast(game, FiniteTimeGame));
    }

    public function removeEnded(id:Int) 
    {
        finite.remove(id);
        correspondence.remove(id);
    }

    public function unloadDerelictCorrespondence(id:Int) 
    {
        correspondence.remove(id);
        Logger.serviceLog('GAMEMGR', 'Derelict game $id removed');
    }

    public function new()
    {
        
    }
}