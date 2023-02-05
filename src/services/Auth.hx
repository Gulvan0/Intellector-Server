package services;

import haxe.Serializer;
import haxe.Unserializer;
import net.SocketHandler;
import entities.UserSession;
import net.shared.utils.MathUtils;
import haxe.crypto.Md5;

class Auth 
{
    private static inline final serviceName:String = "AUTH";

    private static var passwordHashes:Map<String, String>;

    private static var tokenBySessionID:Map<Int, String> = [];
    private static var userByToken:Map<String, UserSession> = [];
    private static var userBySessionID:Map<Int, UserSession> = [];

    private static var lastSessionID:Int = 0;

    public static function createSession(connection:SocketHandler)
    {
        var id:Int = ++lastSessionID;
        var token:String = generateSessionToken();
        var user:UserSession = new UserSession(connection, id);

        tokenBySessionID.set(id, token);
        userByToken.set(token, user);
        userBySessionID.set(id, user);

        Logger.serviceLog(serviceName, 'Session created for $user: $token');
        return user;
    }

    public static function detachSession(id:Int) 
    {
        var token:String = tokenBySessionID.get(id);

        if (token == null)
        {
            Logger.logError('Failed to detach session with id $id: not found');
            return;
        }

        tokenBySessionID.remove(id);
        userByToken.remove(token);
        userBySessionID.remove(id);
        Logger.serviceLog(serviceName, 'Session detached by timeout: $id');
    }

    public static function getUserByRef(userRef:String):Null<UserSession>
    {
        if (isGuest(userRef))
            return getUserBySessionID(Std.parseInt(userRef.substr(1)));
        else
            return LoginManager.getUser(userRef);
    }

    public static function getUserBySessionID(id:Int):Null<UserSession> 
    {
        return userBySessionID.get(id);
    }

    public static function getUserBySessionToken(token:String):Null<UserSession>
    {
        return userByToken.get(token);
    }

    public static function getTokenBySessionID(id:Int):Null<String> 
    {
        return tokenBySessionID.get(id);
    }

    public static function sessionExists(id:Int):Bool
    {
        return userBySessionID.exists(id);
    }

    public static function guestSessionExists(ref:String):Bool
    {
        var id:Null<Int> = Std.parseInt(ref.substr(1));
        return isGuest(ref) && id != null && sessionExists(id);
    }

    private static function generateSessionToken():String
    {
        var token:String = "_";
        for (i in 0...25)
            token += String.fromCharCode(MathUtils.randomInt(33, 126));
        
        return userByToken.exists(token)? generateSessionToken() : token;
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

    public static function getHash(login:String):String 
    {
        return passwordHashes.get(login);
    }

    public static function getAllUsers():Array<String> 
    {
        return [for (login in passwordHashes.keys()) login];
    }

    public static function addCredentials(login:String, password:String) 
    {
        if (passwordHashes.exists(login))
            Logger.serviceLog(serviceName, 'Adding credentials for $login');
        else
            Logger.serviceLog(serviceName, 'Changing password for $login');
        
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