package database.endpoints;

import database.returned.UpdatePasswordResult;
import database.returned.RegisterResult;
import haxe.crypto.Md5;

using database.ScalarGetters;

class Player 
{
    public static function getPasswordHash(database:Database, login:String):Null<String>
    {
        var conditions:Array<String> = [
            Conditions.equals("player_login", login)
        ];
        var columns:Array<String> = [
            "password_hash"
        ];

        return database.filter("player.player", conditions, columns).getScalarString();
    }

    public static function register(database:Database, login:String, password:String):RegisterResult
    {
        if (getPasswordHash(database, login) == null)
        {
            var row:Array<Dynamic> = [
                login, 
                Md5.encode(password)
            ];

            database.insertRow("player.player", row, false);

            return Registered;
        }
        else
            return PlayerAlreadyExists;
    }

    public static function updatePassword(database:Database, login:String, password:String):UpdatePasswordResult
    {
        if (getPasswordHash(database, login) != null)
        {
            var updates:Map<String, Dynamic> = [
                "password_hash" => Md5.encode(password)
            ];
            var conditions:Array<String> = [
                Conditions.equals("player_login", login)
            ];

            database.update("player.player", updates, conditions);

            return Updated;
        }
        else
            return PlayerNonexistent;
    }

    //TODO: Rewrite as endpoints

    /*
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
    */
}