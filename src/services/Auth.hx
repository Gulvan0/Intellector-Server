package services;

import haxe.Serializer;
import haxe.Unserializer;
import net.SocketHandler;
import entities.UserSession;
import utils.MathUtils;
import haxe.crypto.Md5;

class Auth 
{
    private static inline final serviceName:String = "AUTH";

    private static var passwordHashes:Map<String, String>;

    private static var userByToken:Map<String, UserSession> = [];

    public static function createSession(connection:SocketHandler):UserSession
    {
        var token:String = generateSessionToken();
        var user:UserSession = new UserSession(connection, token);
        userByToken.set(token, user);
        Logger.serviceLog(serviceName, 'Session created for ${user.getLogReference()}: $token');
        return user;
    }

    public static function detachSession(token:String) 
    {
        userByToken.remove(token);
        Logger.serviceLog(serviceName, 'Session detached by timeout: $token');
    }

    public static function getUserByInteractionReference(userRef:String):Null<UserSession>
    {
        if (isGuest(userRef))
            return getUserBySessionToken(userRef);
        else
            return LoginManager.getUser(userRef);
    }

    public static function getUserBySessionToken(token:String):Null<UserSession>
    {
        return userByToken.get(token);
    }

    private static function generateSessionToken():String
    {
        var token:String = "_";
        for (i in 0...25)
            token += String.fromCharCode(MathUtils.randomInt(33, 126));
        return token;
    }

    public static function isGuest(userRef:String) 
    {
        return userRef.charAt(0) == '_';    
    }

    public static function isValid(login:String, password:String):Bool 
    {
        var hash:String = encodePassword(password);
        Logger.serviceLog(serviceName, 'Obtained hash for $login auth attempt: $hash');
        if (passwordHashes.exists(login))
            return passwordHashes[login] == hash;
        else
            return false;
    }

    public static function addCredentials(login:String, password:String) 
    {
        passwordHashes[login] = encodePassword(password);
        savePasswords();
    }

    public static function userExists(login:String):Bool 
    {
        return passwordHashes.exists(login);
    }

    private static function savePasswords() 
    {
        try 
        {
            Storage.overwrite(PasswordHashes, Serializer.run(passwordHashes));
        }
        catch (e)
        {
            Logger.logError('Failed to save the map containing the password hashes:\n$e');
        }
    }

    public static function loadPasswords() 
    {
        var contents:String = Storage.read(PasswordHashes);
        if (contents == "")
        {
            Logger.serviceLog(serviceName, 'Warning: no password file found, initializing with empty map');
            passwordHashes = [];
            savePasswords();
            return;
        }

        if (passwordHashes != null)
        {
            Logger.logError("Attempted to load password hashes, but the map has already been initialized before");
            return;
        }

        try 
        {
            passwordHashes = Unserializer.run(contents);
        }
        catch (e)
        {
            Logger.logError('Failed to deserialize the map containing the password hashes:\n$e');
            return;
        }
    }
    
    private static function encodePassword(password:String):String
    {
        return Md5.encode(password);
    }
}