package database;

import haxe.crypto.Md5;
import database.action_results.RegisterResult;
import database.QueryShortcut;

class CompositeActions 
{
    public static function register(database:Database, login:String, password:String):RegisterResult
    {
        if (TypedRetrievers.playerPasswordHash(database, login) == null)
        {
            database.executeQuery(SetPasswordHash, [
                "player_login" => login,
                "password_hash" => Md5.encode(password)
            ]);
            return Registered;
        }
        else
            return PlayerAlreadyExists;
    } 
}