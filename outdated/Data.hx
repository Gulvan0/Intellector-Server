package;

import subsystems.Librarian.StudyData;
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

enum Segment
{
    Games;
    Studies;
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
        Data.overwrite(logPath(gameID),log);
    }

    public static function writePlayerdata(login:String, playerdata:Playerdata) 
    {
        overwrite(playerdataPath(login), Json.stringify(playerdata, null, "    "));    
    }

    public static function writeStudy(id:Int, data:StudyData) 
    {
        overwrite(studyPath(id), Json.stringify(data, null, "    "));    
    }

    public static function editPlayerdata(login:String, mutator:Playerdata->Playerdata) 
    {
        var pd = getPlayerdata(login);
        pd = mutator(pd);
        writePlayerdata(login, pd);
    }

    public static function read(absPath:String):String
    {
        return File.getContent(absPath);
    }

    public static function getCurrID(segment:Segment):Int 
    {
        var dir:String = switch segment 
        {
            case Games: 'games/';
            case Studies: 'studies/';
        };
        var absPath = convertPath(dir + "currid.txt");
        var currID = Std.parseInt(Data.read(absPath));
        currID++;
        Data.overwrite(absPath, '$currID');
        return currID;
    }

    public static function overwrite(absPath:String, content:String)
    {
        File.saveContent(absPath, content);
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

    public static function studyExists(id:Int):Bool
    {
        return FileSystem.exists(studyPath(id));
    }

    public static function playerdataExists(login:String) 
    {
        return FileSystem.exists(playerdataPath(login));
    }

    public static function appendResultToAbortedGames() 
    {
        var id = Std.parseInt(Data.read(convertPath("games/currid.txt")));
        while (id > 50)
        {
            var log:String = Data.read(convertPath('games/$id.txt'));
            if (StringTools.contains(log, "#R|"))
            {
                trace('ID $id: Result data found');
                break;
            }
            else
            {
                trace('ID $id: No result');
                Data.writeGameLog(id, log + "#R|d/abo");
                id--;
            }
        }
    }

    public static function appendResultToAbortedGame(id:Int) 
    {
        var log:String = Data.read(convertPath('games/$id.txt'));
        if (StringTools.contains(log, "#R|"))
            trace("Warning: appendResultToAbortedGame() called, but log contains result data"); //TODO: Notify myself
        else
            Data.writeGameLog(id, log + "#R|d/abo");
    }

    public static function getLog(gameId:Int):String
    {
        return read(logPath(gameId));
    }

    public static function getStudy(id:Int):StudyData
    {
        return Json.parse(read(studyPath(id)));
    }

    public static function getPlayerdata(login:String):Playerdata
    {
        return Json.parse(read(playerdataPath(login)));
    }

    private static function logPath(gameId:Int) 
    {
        return convertPath('games/$gameId.txt');    
    }

    private static function studyPath(id:Int) 
    {
        return convertPath('studies/$id.txt');    
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