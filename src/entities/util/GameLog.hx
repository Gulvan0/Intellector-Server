package entities.util;

import net.shared.Constants;
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
    public var customStartingSituation(default, null):Null<Situation>;
    
    public function get():String
    {
        return log;
    }

    public function getEntries():Array<GameLogEntry>
    {
        return entries.copy();    
    }

    public function getColorByLogin(login:String):Null<PieceColor> 
    {
        if (playerLogins.get(White) == login)
            return White;
        else if (playerLogins.get(Black) == login)
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
            case Players(whiteLogin, blackLogin):
                playerLogins = [White => whiteLogin, Black => blackLogin];
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
                case Move(from, to, morphInto, msLeftWhite, msLeftBlack):
                    if (bonusTimeReceiverColor == White)
                        entries[i] = Move(from, to, morphInto, msLeftWhite + Constants.msAddedByOpponent, msLeftBlack);
                    else
                        entries[i] = Move(from, to, morphInto, msLeftWhite, msLeftBlack + Constants.msAddedByOpponent);
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

    public static function load(id:Int):Null<GameLog>
    {
        var logStr = Storage.getGameLog(id);

        if (logStr == null)
            return null;

        var log:GameLog = new GameLog(id);

        for (entry in GameLogTranslator.parse(logStr))
            log.append(entry, false);

        return log;
    }

    public static function createNew(id:Int, players:Map<PieceColor, Null<UserSession>>, timeControl:TimeControl, rated:Bool, ?customStartingSituation:Situation):GameLog 
    {
        var log:GameLog = new GameLog(id);

        var timeControlType:TimeControlType = timeControl.getType();

        var eloValues:Map<PieceColor, EloValue> = [White => None, Black => None];

        for (color => player in players.keyValueIterator())
            if (player != null && player.login != null && player.storedData != null)
                eloValues[color] = player.storedData.getELO(timeControlType);
        
        log.append(Players(players[White].login, players[Black].login), false);
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