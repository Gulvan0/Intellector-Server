package services;

import utils.ds.DefaultArrayMap;
import entities.UserSession;

class SpectatorManager
{
    private static var playerFollowersByLogin:DefaultArrayMap<String, UserSession> = new DefaultArrayMap([]);
    private static var gameIDBySpectatorLogin:Map<String, Int> = [];

    public static function getFollowers(playerLogin:String):Array<UserSession>
    {
        return playerFollowersByLogin.get(playerLogin);
    }

    public static function getSpectatedGameID(spectatorLogin:String):Null<Int>
    {
        return gameIDBySpectatorLogin.get(spectatorLogin);
    }

    //TODO: Fill
}