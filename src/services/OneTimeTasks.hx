package services;

import sys.io.File;
import net.shared.board.Situation;
import net.shared.Outcome;
import net.shared.PieceColor;
import entities.util.GameLog;
import stored.PlayerData;
import entities.UserSession;
using StringTools;

class OneTimeTasks
{
    public static function recountGames() 
    {
        var dataMap:Map<String, PlayerData> = [];
        for (user in LoginManager.getLoggedUsers())
        {
            user.storedData.resetGames();
            dataMap.set(user.login, user.storedData);
        }

        for (login in Auth.getAllUsers())
            if (!dataMap.exists(login))
            {
                var data = Storage.loadPlayerData(login);
                data.resetGames();
                dataMap.set(login, data);
            }

        var lastGameID:Int = GameManager.getLastGameID();
        var gameID:Int = 0;

        while (gameID++ < lastGameID)
        {
            var anyGame = GameManager.get(gameID);

            switch anyGame 
            {
                case OngoingFinite(game):
                    for (color in PieceColor.createAll())
                    {
                        var playerRef:String = game.log.playerRefs.get(color);
                        if (Auth.isGuest(playerRef))
                            continue;

                        var data:PlayerData = dataMap[playerRef];
                        data.addOngoingFiniteGame(gameID);
                    }
                case OngoingCorrespondence(game):
                    for (color in PieceColor.createAll())
                    {
                        var playerRef:String = game.log.playerRefs.get(color);
                        if (Auth.isGuest(playerRef))
                            continue;

                        var data:PlayerData = dataMap[playerRef];
                        data.addOngoingCorrespondenceGame(gameID);
                    }
                case Past(log):
                    var gameLog:GameLog = GameLog.loadFromStr(gameID, log);

                    for (color in PieceColor.createAll())
                    {
                        var playerRef:String = gameLog.playerRefs.get(color);
                        if (Auth.isGuest(playerRef))
                            continue;
                        
                        var data:PlayerData = dataMap[playerRef];
                        
                        if (data != null)
                        {
                            if (gameLog.rated && !gameLog.outcome.match(Drawish(Abort)))
                            {
                                var newElo = GameManager.getNewElo(color, data, gameLog.outcome, gameLog);
                                data.addPastGame(gameID, gameLog.timeControl.getType(), newElo);
                            }
                            else
                                data.addPastGame(gameID, gameLog.timeControl.getType(), null);
                        }
                    }
                case NonExisting:
                    //Do nothing
            }
        }
    }

    public static function gatherGameArchiveCSV()
    {
        var lastGameID:Int = GameManager.getLastGameID();
        var gameID:Int = 0;
        var s:String = "";

        while (gameID++ < lastGameID)
        {
            var anyGame = GameManager.get(gameID);

            switch anyGame 
            {
                case Past(log):
                    
                    var gameLog:GameLog = GameLog.loadFromStr(gameID, log);

                    var whiteRef:String = gameLog.playerRefs.get(White);
                    var blackRef:String = gameLog.playerRefs.get(Black);

                    if (skippablePlayer(whiteRef) && skippablePlayer(blackRef))
                    {
                        trace("Skipping " + gameID);
                        continue;
                    }
                    else
                        trace("Processing " + gameID);
                    
                    s += gameID;
                    s += ";";
                    s += 'https://intellector.info/game/?p=live/$gameID';
                    s += ";";
                    s += gameLog.datetime == null? "" : gameLog.datetime.toString();
                    s += ";";
                    s += prettifyRef(whiteRef);
                    s += ";";
                    s += prettifyRef(blackRef);
                    s += ";";
                    s += gameLog.rated? "Рейтинговая" : "Товарищеская";
                    s += ";";
                    s += gameLog.timeControl.toString(true);
                    s += ";";
                    s += gameLog.timeControl.getType().getName();
                    s += ";";
                    switch gameLog.outcome 
                    {
                        case Decisive(type, winnerColor):
                            if (winnerColor == White)
                                s += "Победа белых";
                            else
                                s += "Победа черных";
                            s += ";";
                            switch type 
                            {
                                case Mate:
                                    s += "Фатум";
                                case Breakthrough:
                                    s += "Финиш";
                                case Timeout:
                                    s += "Закончилось время";
                                case Resign:
                                    s += "Игрок сдался";
                                case Abandon:
                                    s += "Игрок покинул игру";
                            }
                        case Drawish(type):
                            s += "Ничья";
                            s += ";";
                            switch type 
                            {
                                case DrawAgreement:
                                    s += "По согласию";
                                case Repetition:
                                    s += "По троекратному повторению";
                                case NoProgress:
                                    s += "По правилу 60 ходов";
                                case Abort:
                                    s += "Прервана";
                            }
                    }
                    s += ";";
                    s += gameLog.moves.length;
                    s += ";";
                    var sit:Situation = Situation.defaultStarting();
                    if (gameLog.customStartingSituation == null || gameLog.customStartingSituation.isDefaultStarting())
                        s += "Стандартная";
                    else
                    {
                        sit = gameLog.customStartingSituation.copy();
                        s += sit.serialize();
                    }
                    s += ";";
                    for (move in gameLog.moves.slice(0, 8))
                    {
                        s += move.toNotation(sit, false);
                        s += ";";
                        sit.performRawPly(move);
                    }
                    s += '\n';
                default:
                    trace("Ignoring " + gameID);
            }
        }

        File.write('./games.csv', false).writeString(s);
    }

    private static function prettifyRef(ref:String) 
    {
        return switch ref.charAt(0) 
        {
            case "+": "Бот " + ref.substr(1);
            case "_": "Гость " + ref.substr(1);
            default: ref;
        }
    }

    private static function skippablePlayer(ref:String):Bool
    {
        if (ref.charAt(0) == "+")
            return true;
        else if (ref.charAt(0) == "_")
            return true;
        else if (ref == "gulvan")
            return true;
        else if (ref == "kazvixx")
            return true;
        else if (ref == "kaz")
            return true;
        else if (ref == "mrsalatik")
            return true;
        else
            return false;
    }
}