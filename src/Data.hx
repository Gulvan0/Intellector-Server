package;

import sys.FileSystem;
using StringTools;
import sys.io.File;

class Data
{
    public static function read(path:String):String
    {
        return File.getContent(convertPath(path));
    }

    public static function overwrite(path:String, content:String)
    {
        File.saveContent(convertPath(path), content);
    }

    public static function append(path:String, content:String)
    {
        var fo = File.append(convertPath(path), false);
        fo.writeString(content);
        fo.close();
    }

    public static function logExists(gameId:Int):Bool
    {
        return FileSystem.exists(convertPath(logPath(gameId)));
    }

    public static function getLog(gameId:Int):String
    {
        return read(logPath(gameId));
    }

    private static function logPath(gameId:Int) 
    {
        return 'games/$gameId.txt';    
    }

    private static function convertPath(s:String):String
    {
        var progPath = Sys.programPath();
        return progPath.substring(0, progPath.lastIndexOf("\\") + 1) + s.replace("/", "\\");
    }
}