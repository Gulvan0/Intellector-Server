package entities.util;

import net.shared.PieceColor;
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

    public var playerLogins(default, null):Map<PieceColor, Null<String>>;
    public var timeControl(default, null):TimeControl;
    public var ongoing(default, null):Bool = true;
    public var rated(default, null):Bool;
    public var elo(default, null):Map<PieceColor, EloValue>;
    public var msLeftOnOver(default, null):Null<Map<PieceColor, Int>>;
    
    public function get():String
    {
        return log;
    }

    public function getEntries():Array<GameLogEntry>
    {
        return entries.copy();    
    }

    public function save() 
    {
        Storage.overwrite(GameData(gameID), log);
    }

    public function append(entry:GameLogEntry, ?saveToStorage:Bool = true) 
    {
        log = GameLogTranslator.concat(log, entry);
        entries.push(entry);

        switch entry 
        {
            case Players(whiteLogin, blackLogin):
                playerLogins = [White => whiteLogin, Black => blackLogin];
            case Elo(whiteElo, blackElo):
                rated = true;
                elo = [White => whiteElo, Black => blackElo];
            case TimeControl(tc):
                timeControl = tc;
            case MsLeft(whiteMs, blackMs):
                msLeftOnOver = [White => whiteMs, Black => blackMs];
            case Result(_):
                ongoing = false;
            default:
        }

        if (saveToStorage)
            save();
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

        var logStr = Storage.getGameLog(id);

        if (logStr == null)
            throw 'Failed to load the log for game $id';

        for (entry in GameLogTranslator.parse(logStr))
            log.append(entry, false);

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
        
        log.append(Players(whitePlayer.login, blackPlayer.login), false);
        log.append(Elo(whiteElo, blackElo), false);
        log.append(DateTime(Date.now()), false);
        log.append(TimeControl(timeControl), false);
        if (customStartingSituation != null)
            log.append(CustomStartingSituation(customStartingSituation), false);

        log.save();

        return log;
    }

    private function new(gameID:Int) 
    {
        this.gameID = gameID;
    }
}