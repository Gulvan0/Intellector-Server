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
                var data = Storage.loadPlayerData(login);
                data.resetGames();
                dataMap.set(login, data);
            }

        var lastGameID:Int = GameManager.getLastGameID();
        var gameID:Int = 5681;

        while (gameID++ < lastGameID)
        {
            var anyGame = GameManager.get(gameID);

            switch anyGame 
            {
                case OngoingCorrespondence(game):
                    for (color in PieceColor.createAll())
                    {
                        var playerRef:String = game.log.playerRefs.get(color);
                        if (Auth.isGuest(playerRef) || playerRef.charAt(0) == "+")
                            continue;

                        var data:PlayerData = dataMap[playerRef];
                        data.addOngoingCorrespondenceGame(gameID, true);
                    }
                default:
            }
        }
    }
}