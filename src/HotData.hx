package;

import sys.FileSystem;
import haxe.Unserializer;
import haxe.Serializer;
import sys.io.File;
import haxe.io.Path;
import utils.sieve.StringSieve;

private enum abstract DataFieldKey(String) to String
{
    var AlertSieve;
}

class HotData 
{
    private static var instance:HotData;

    public static function getInstance():HotData
    {
        return instance;
    }

    public var alertSieve:StringSieve;

    public function init()
    {
        if (FileSystem.exists(getDumpPath()))
            load();
        else
            initEmpty(); 

        HotData.instance = this;
    }
    
    public function save() 
    {
        var map:Map<String, String> = [
            AlertSieve => alertSieve.dumps()
        ];

        File.saveContent(getDumpPath(), Serializer.run(map));
    }

    private function load()
    {
        var dmpStr:String = File.getContent(getDumpPath());
        var map:Map<String, String> = Unserializer.run(dmpStr);

        alertSieve = new StringSieve(map[AlertSieve]);
    }

    private function initEmpty() 
    {
        alertSieve = new StringSieve();
    }

    private function getDumpPath():String
    {
        return Path.directory(Sys.programPath()) + '/hot.dmp';
    }
}