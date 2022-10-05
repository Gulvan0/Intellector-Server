package;

import haxe.Serializer;
import services.Auth;
import services.Logger;
import haxe.Unserializer;
import services.Storage;

class Routines
{
    public static function onStartup() 
    {
        Serializer.USE_ENUM_INDEX = true;
        
        Storage.createMissingFiles();
        Configuration.load();

        hx.ws.Log.mask = Configuration.logMask;
        Storage.repairGameLogs();
        Auth.loadPasswords();
    }

    //TODO: Regular processes
}