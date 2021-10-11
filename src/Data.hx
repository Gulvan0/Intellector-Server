package;

import haxe.Json;
import sys.FileSystem;
using StringTools;
import sys.io.File;

typedef Playerdata = 
{
    var passwordMD5:String;
    var games:Array<Int>;
    var studies:Array<Int>;
    var puzzles:Array<Int>;
}

class Data
{
    public static function writeLog(folder:String, entry:String)
    {
        var datetime:String = Date.now().toString();
        var date_time:Array<String> = datetime.split(" ");
        var logPath:String = folder + date_time[0] + ".txt";
        var line:String = date_time[1] + " " + entry + "\n";
        append(logPath, line);
    }

    public static function writeGameLog(gameID:Int, log:String) 
    {
        Data.overwrite('games/${gameID}.txt',log);
    }

    public static function writePlayerdata(login:String, playerdata:Playerdata) 
    {
        overwrite(playerdataPath(login), Json.stringify(playerdata, null, "    "));    
    }

    public static function editPlayerdata(login:String, mutator:Playerdata->Playerdata) 
    {
        var pd = getPlayerdata(login);
        pd = mutator(pd);
        writePlayerdata(login, pd);
    }

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
        return FileSystem.exists(logPath(gameId));
    }

    public static function playerdataExists(login:String) 
    {
        return FileSystem.exists(playerdataPath(login));
    }

    public static function getLog(gameId:Int):String
    {
        return read(logPath(gameId));
    }

    public static function getPlayerdata(login:String):Playerdata
    {
        return Json.parse(read(playerdataPath(login)));
    }

    private static function logPath(gameId:Int) 
    {
        return convertPath('games/$gameId.txt');    
    }

    private static function playerdataPath(login:String) 
    {
        return convertPath('playerdata/$login.json');    
    }

    private static function convertPath(s:String):String
    {
        var progPath = Sys.programPath();
        #if prod
        return progPath.substring(0, progPath.lastIndexOf("/") + 1) + s;
        #else
        return progPath.substring(0, progPath.lastIndexOf("\\") + 1) + s.replace("/", "\\");
        #end
    }
}