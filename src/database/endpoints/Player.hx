package database.endpoints;

import database.returned.RemoveFriendResult;
import database.returned.AddFriendResult;
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

    public static function playerExists(database:Database, login:String):Bool
    {
        return getPasswordHash(database, login) != null;
    }

    public static function register(database:Database, login:String, password:String):RegisterResult
    {
        if (!playerExists(database, login))
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
        if (playerExists(database, login))
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

    public static function isFriend(database:Database, friendOwnerLogin:String, friendLogin:String):Bool
    {
        return database.filter("player.friend_pair", [
            Conditions.equals("friend_owner_login", friendOwnerLogin),
            Conditions.equals("friend_login", friendLogin)
        ]).hasNext();
    }

    public static function addFriend(database:Database, authorLogin:String, friendLogin:String):AddFriendResult
    {
        if (isFriend(database, authorLogin, friendLogin))
            return AlreadyFriends;
        else if (!playerExists(database, authorLogin))
            return AuthorNonexistent;
        else if (!playerExists(database, friendLogin))
            return FriendNonexistent;

        database.insertRow("player.friend_pair", [authorLogin, friendLogin]);

        return Added;
    }

    public static function removeFriend(database:Database, authorLogin:String, friendLogin:String):RemoveFriendResult
    {
        if (!playerExists(database, authorLogin))
            return AuthorNonexistent;
        else if (!playerExists(database, friendLogin))
            return FriendNonexistent;

        database.delete("player.friend_pair", [
            Conditions.equals("friend_owner_login", authorLogin),
            Conditions.equals("friend_login", friendLogin)
        ]);

        return Removed;
    }

    //TODO: Rewrite as endpoints

    /*
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