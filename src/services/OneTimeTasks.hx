package services;

import net.shared.Outcome;
import net.shared.PieceColor;
import entities.util.GameLog;
import stored.PlayerData;
import entities.UserSession;

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
                var data = Storage.loadPlayerData(login, true);
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
}