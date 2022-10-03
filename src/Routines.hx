package;

import services.Auth;
import services.Logger;
import haxe.Unserializer;
import services.Storage;

class Routines
{
    public static function onStartup() 
    {
        //TODO: Fix broken logs, if any
        loadPasswords();
    }

    //TODO: Regular processes

    private static function loadPasswords() 
    {
        var contents:String = Storage.read(PasswordHashes);
        if (contents == "")
            return;

        var map:Map<String, String> = [];
        try 
        {
            Unserializer.run(contents);
        }
        catch (e)
        {
            Logger.logError('Failed to deserialize the map containing the password hashes:\n$e');
            return;
        }
        
        Auth.loadHashes(map);
    }
}