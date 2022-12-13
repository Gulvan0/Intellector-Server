package services;

import net.shared.TimeControlType;
import net.shared.dataobj.GameInfo;
import stored.PlayerData;
import entities.UserSession;

class ProfileManager
{
    public static function addFriend(author:UserSession, login:String) 
    {
        Logger.serviceLog('PROFILEMGR', '$author wants to add $login as a friend');
        if (Auth.userExists(login))
        {
            author.storedData.addFriend(login);
            Logger.serviceLog('PROFILEMGR', 'Success: $author and $login are now friends');
        }
        else
        {
            author.emit(PlayerNotFound);
            Logger.serviceLog('PROFILEMGR', 'Fail: $login not found');
        }
    }

    public static function removeFriend(author:UserSession, login:String) 
    {
        Logger.serviceLog('PROFILEMGR', '$author wants to remove $login from their friend list');
        if (Auth.userExists(login))
        {
            author.storedData.removeFriend(login);
            Logger.serviceLog('PROFILEMGR', 'Success: $author and $login are no longer friends');
        }
        else
        {
            author.emit(PlayerNotFound);
            Logger.serviceLog('PROFILEMGR', 'Fail: $login not found');
        }
    }

    public static function isFriend(author:UserSession, login:String):Bool
    {
        if (Auth.userExists(login))
            return author.storedData.hasFriend(login);
        else
            return false;
    }

    public static function getProfile(author:UserSession, login:String) 
    {
        if (Auth.userExists(login))
            author.emit(PlayerProfile(Storage.loadPlayerData(login).toProfileData(author)));
        else
            author.emit(PlayerNotFound);
    }

    public static function getMiniProfile(author:UserSession, login:String) 
    {
        if (Auth.userExists(login))
            author.emit(MiniProfile(Storage.loadPlayerData(login).toMiniProfileData(author)));
        else
            author.emit(PlayerNotFound);
    }

    public static function getPastGames(author:UserSession, login:String, after:Int, pageSize:Int, filterByTimeControl:Null<TimeControlType>) 
    {
        if (!Auth.userExists(login))
        {
            author.emit(PlayerNotFound);
            return;
        }

        var data:PlayerData = Storage.loadPlayerData(login);
        var games:Array<GameInfo> = data.getPastGames(after, pageSize, filterByTimeControl);
        var hasNext:Bool = data.getPlayedGamesCnt(filterByTimeControl) > after + pageSize;
        author.emit(Games(games, hasNext));
    }

    public static function getStudies(author:UserSession, login:String, after:Int, pageSize:Int, filterByTags:Null<Array<String>>) 
    {
        if (!Auth.userExists(login))
        {
            author.emit(PlayerNotFound);
            return;
        }

        var data:PlayerData = Storage.loadPlayerData(login);
        var studies = data.getStudies(after, pageSize, filterByTags);
        author.emit(Studies(studies.map, studies.hasNext));
    }

    public static function getOngoingGames(author:UserSession, login:String) 
    {
        if (!Auth.userExists(login))
        {
            author.emit(PlayerNotFound);
            return;
        }

        var data:PlayerData = Storage.loadPlayerData(login);
        var gameIDs:Array<Int> = data.getOngoingGameIDs();
        var games:Array<GameInfo> = Storage.getGameInfos(gameIDs);
        author.emit(Games(games, false));
    }
}