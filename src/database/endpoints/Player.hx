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
}