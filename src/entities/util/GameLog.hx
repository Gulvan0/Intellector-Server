package entities.util;

import struct.Situation;
import net.shared.TimeControlType;
import net.shared.EloValue;
import struct.TimeControl;
import services.EloManager;
import services.Storage;

class GameLog 
{
    private var gameID:Int;
    private var log:String = "";
    private var entries:Array<GameLogEntry> = []; //Pay special attention to keeping it in sync with the `log` property
    
    public function get():String
    {
        return log;
    }

    public function append(entry:GameLogEntry) 
    {
        log = GameLogTranslator.concat(log, entry);
        entries.push(entry);

        Storage.overwrite(GameData(gameID), log);
    }

    public function rollback(moveCnt:Int) 
    {
        var splittedLog:Array<String> = GameLogTranslator.split(log);
        var movesToEraseLeft:Int = moveCnt;
        var i:Int = entries.length - 1;

        while (movesToEraseLeft > 0 && i >= 0)
        {
            switch entries[i] 
            {
                case Move(_, _, _, _, _):
                    entries.splice(i, 1);
                    splittedLog.splice(i, 1);
                    movesToEraseLeft--;
                default:
                    //Keep entry
            }

            i--;
        }

        log = GameLogTranslator.join(splittedLog); //Entries have already been filtered inside the loop above

        Storage.overwrite(GameData(gameID), log);
    }

    public static function load(id:Int):GameLog
    {
        var log:GameLog = new GameLog(id);

        log.log = Storage.getGameLog(id);

        if (log.log == null)
            throw 'Failed to load the log for game $id';

        log.entries = GameLogTranslator.parse(log.log);

        return log;
    }

    public static function createNew(id:Int, whitePlayer:UserSession, blackPlayer:UserSession, timeControl:TimeControl, ?customStartingSituation:Situation):GameLog 
    {
        var log:GameLog = new GameLog(id);

        var timeControlType:TimeControlType = timeControl.getType();

        var whiteElo:EloValue;
        var blackElo:EloValue;

        if (whitePlayer.login != null && whitePlayer.storedData != null)
        {
            whiteElo = whitePlayer.storedData.getELO(timeControlType);
            if (whiteElo == null)
                whiteElo = None;
        }

        if (blackPlayer.login != null && blackPlayer.storedData != null)
        {
            blackElo = blackPlayer.storedData.getELO(timeControlType);
            if (blackElo == null)
                blackElo = None;
        }
        
        log.append(Players(whitePlayer.login, blackPlayer.login));
        log.append(Elo(whiteElo, blackElo));
        log.append(DateTime(Date.now()));
        log.append(TimeControl(timeControl));
        if (customStartingSituation != null)
            log.append(CustomStartingSituation(customStartingSituation));

        return log;
    }

    private function new(gameID:Int) 
    {
        this.gameID = gameID;
    }
}