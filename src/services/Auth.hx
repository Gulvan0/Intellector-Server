package services;

import haxe.crypto.Md5;

class Auth 
{
    private static inline final serviceName:String = "AUTH";

    private static var passwordHashes:Map<String, String>;

    public static function isValid(login:String, password:String):Bool 
    {
        var hash:String = encodePassword(password);
        Logger.serviceLog(serviceName, 'Obtained hash for $login auth attempt: $hash');
        if (passwordHashes.exists(login))
            return passwordHashes[login] == hash;
        else
            return false;
    }

    public static function loadHashes(hashes:Map<String, String>) 
    {
        if (passwordHashes != null)
            Logger.logError("Attempted to load password hashes, but the map has already been initialized before");
        else
            passwordHashes = hashes;
    }
    
    private static function encodePassword(password:String):String
    {
        return Md5.encode(password);
    }
}