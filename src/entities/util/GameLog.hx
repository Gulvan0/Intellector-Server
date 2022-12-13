package entities.util;

import net.shared.Constants;
import net.shared.PieceColor;
import net.shared.board.Situation;
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

    public var playerRefs(default, null):Map<PieceColor, String>;
    public var timeControl(default, null):TimeControl;
    public var ongoing(default, null):Bool = true;
    public var rated(default, null):Bool;
    public var elo(default, null):Map<PieceColor, EloValue>;
    public var msLeftOnOver(default, null):Null<Map<PieceColor, Int>>;
    public var customStartingSituation(default, null):Null<Situation>;
    
    public function get():String
    {
        return log;
    }

    public function getEntries():Array<GameLogEntry>
    {
        return entries.copy();    
    }

    public function getColorByRef(user:UserSession):Null<PieceColor> 
    {
        var ref:String = user.getReference();

        if (playerRefs.get(White) == ref)
            return White;
        else if (playerRefs.get(Black) == ref)
            return Black;
        else 
            return null;
    }

    public function save() 
    {
        Storage.overwrite(GameData(gameID), log);
    }

    private function saveFromEntryArray() 
    {
        log = GameLogTranslator.fromEntries(entries);
        save();
    }

    public function append(entry:GameLogEntry, ?saveToStorage:Bool = true) 
    {
        log = GameLogTranslator.concat(log, entry);
        entries.push(entry);

        switch entry 
        {
            case Players(whiteRef, blackRef):
                playerRefs = [White => whiteRef, Black => blackRef];
            case Elo(whiteElo, blackElo):
                rated = true;
                elo = [White => whiteElo, Black => blackElo];
            case TimeControl(tc):
                timeControl = tc;
            case CustomStartingSituation(situation):
                customStartingSituation = situation;
            case MsLeft(whiteMs, blackMs):
                msLeftOnOver = [White => whiteMs, Black => blackMs];
            case Result(_):
                ongoing = false;
            default:
        }

        if (saveToStorage)
            save();
    }

    public function addTime(bonusTimeReceiverColor:PieceColor) 
    {
        var i:Int = entries.length - 1;

        while (i >= 0)
        {
            var entry:GameLogEntry = entries[i];
            switch entry 
            {
                case Move(rawPly, msLeftWhite, msLeftBlack):
                    if (bonusTimeReceiverColor == White)
                        entries[i] = Move(rawPly, msLeftWhite + Constants.msAddedByOpponent, msLeftBlack);
                    else
                        entries[i] = Move(rawPly, msLeftWhite, msLeftBlack + Constants.msAddedByOpponent);
                    entries.push(Event(TimeAdded(bonusTimeReceiverColor)));
                    saveFromEntryArray();
                    return;
                default:
            }
        }
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
                case Move(_, _, _):
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

    public static function load(id:Int):Null<GameLog>
    {
        var logStr = Storage.getGameLog(id);

        if (logStr == null)
            return null;

        var log:GameLog = new GameLog(id);

        for (entry in GameLogTranslator.parse(logStr))
            log.append(entry, false);

        if (log.timeControl == null)
            log.timeControl = TimeControl.correspondence();

        return log;
    }

    public static function createNew(id:Int, players:Map<PieceColor, UserSession>, timeControl:TimeControl, rated:Bool, ?customStartingSituation:Situation):GameLog 
    {
        var log:GameLog = new GameLog(id);

        var timeControlType:TimeControlType = timeControl.getType();

        var eloValues:Map<PieceColor, EloValue> = [White => None, Black => None];

        for (color => player in players.keyValueIterator())
            if (player != null && player.login != null && player.storedData != null)
                eloValues[color] = player.storedData.getELO(timeControlType);
        
        log.append(Players(players[White].getReference(), players[Black].getReference()), false);
        if (rated)
            log.append(Elo(eloValues[White], eloValues[Black]), false);
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