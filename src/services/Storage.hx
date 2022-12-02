package services;

import net.shared.dataobj.GameInfo;
import entities.util.GameLog;
import entities.util.GameLogEntry;
import stored.StudyData;
import utils.MovingCountdownTimer;
import haxe.Timer;
import entities.util.GameLogTranslator;
import haxe.io.Path;
import stored.PlayerData;
import sys.FileSystem;
import haxe.Json;
import integration.Telegram;
import sys.io.File;

using StringTools;

enum LogType
{
    Event;
    Error;
    Antifraud;
    Full;
}

enum DataFile
{
    PlayerData(login:String);
    GameData(id:Int);
    StudyData(id:Int);
    Log(type:LogType);
    PasswordHashes;
    ServerConfig;
    ServerData;
}

class Storage 
{
    private static var playerdataCache:Map<String, PlayerData> = [];
    private static var playerdataCleaners:Map<String, MovingCountdownTimer> = [];

    public static function getGameLog(id:Int):Null<String>
    {
        if (!exists(GameData(id)))
            return null;
        else
            return read(GameData(id));
    }

    public static function getGameInfo(id:Int):GameInfo
    {
        var info:GameInfo = new GameInfo();
        info.id = id;
        info.log = getGameLog(id);
        return info;
    }

    public static function getGameInfos(ids:Array<Int>):Array<GameInfo> 
    {
        return ids.map(getGameInfo);
    }

    public static function getStudyData(id:Int):Null<StudyData>
    {
        if (!exists(StudyData(id)))
            return null;

        var contentStr:String = read(StudyData(id));
        var contentJSON:Dynamic = Json.parse(contentStr);
        var contentData:StudyData = stored.StudyData.fromJSON(contentJSON);
        return contentData;
    }

    public static function saveStudyData(id:Int, studyData:StudyData) 
    {
        var content:String = Json.stringify(studyData.toJSON(), null, "    ");
        overwrite(StudyData(id), content);
        Logger.serviceLog("STORAGE", 'Study data overwritten (ID = $id)');
    }

    private static function removeCachedPlayerdata(login:String) 
    {
        playerdataCache.remove(login);
        playerdataCleaners.remove(login);
    }

    private static function startPlayerdataCleaningTimer(login:String) 
    {
        var cleanupTimer:Null<MovingCountdownTimer> = playerdataCleaners.get(login);
        if (cleanupTimer != null)
            cleanupTimer.refresh();
        else
            playerdataCleaners.set(login, new MovingCountdownTimer(removeCachedPlayerdata.bind(login), 10 * 60 * 1000));
    }
    
    public static function loadPlayerData(login:String):PlayerData
    {
        startPlayerdataCleaningTimer(login);

        var cachedValue:Null<PlayerData> = playerdataCache.get(login);

        if (cachedValue != null)
            return cachedValue;

        if (!exists(PlayerData(login)))
        {
            var data:PlayerData = stored.PlayerData.createForNewPlayer(login);
            savePlayerData(login, data);
            Logger.serviceLog("STORAGE", 'Created new data file for player $login');
            playerdataCache.set(login, data);
            return data;
        }

        var content:String = read(PlayerData(login));
        var jsonData:Dynamic = Json.parse(content);
        var data:PlayerData = stored.PlayerData.fromJSON(login, jsonData);
        playerdataCache.set(login, data);
        return data;
    }

    public static function savePlayerData(login:String, playerData:PlayerData) 
    {
        var content:String = Json.stringify(playerData.toJSON(), null, "    ");
        overwrite(PlayerData(login), content);
        Logger.serviceLog("STORAGE", 'Player data overwritten ($login)');
    }

    public static function appendLog(log:LogType, entry:String) 
    {
        var seconds:Float = Sys.time();
        var suffix:String = '${seconds % 1}'.substr(1);
        append(Log(log), '\n### ${Date.fromTime(seconds * 1000).toString()}$suffix ###\n\n$entry\n');
    }

    public static function exists(file:DataFile):Bool
    {
        return FileSystem.exists(filePath(file));
    }

    private static function delete(file:DataFile) 
    {
        var path:String = filePath(file);
        try
        {
            FileSystem.deleteFile(path);
        }
        catch (e)
        {
            Logger.logError('Failed to delete $path:\n${e.details()}');
        }
    }

    public static function read(file:DataFile):String
    {
        var path:String = filePath(file);
        try
        {
            return File.getContent(path);
        }
        catch (e)
        {
            Logger.logError('Failed to read $path:\n${e.details()}');
            return "";
        }
    }

    public static function overwrite(file:DataFile, content:String)
    {
        var path:String = filePath(file);
        try
        {
            File.saveContent(path, content);

            switch file 
            {
                case GameData(id):
                    Logger.serviceLog("STORAGE", 'Log for game $id was updated');
                case PasswordHashes:
                    Logger.serviceLog("STORAGE", 'Password hash map updated');
                case ServerConfig:
                    Logger.serviceLog("STORAGE", 'Server config file updated');
                case ServerData:
                    Logger.serviceLog("STORAGE", 'Server data file updated');
                default:
                    //Skip as modifications of other files must have already been logged somewhere else
            }
        }
        catch (e)
        {
            Logger.logError('Failed to overwrite $path:\n${e.details()}');
        }
    }

    private static function append(file:DataFile, content:String)
    {
        var path:String = filePath(file);
        try
        {
            var stream = File.append(path, false);
            stream.writeString(content);
            stream.close();
        }
        catch (e)
        {
            Logger.logError('Failed to append to $path:\n${e.details()}');
        }
    }

    public static function repairGameLogs() 
    {
        var lastGameID:Int = GameManager.getLastGameID();
        var gameID:Int = getServerDataField("lastRepairedLogID");

        while (gameID++ < lastGameID)
        {
            var log:Null<String> = getGameLog(gameID);

            if (log == null)
            {
                Logger.logError('Missing game log: $gameID');
                continue;
            }

            if (!log.contains("#R|"))
            {
                var parsedLog = GameLog.load(gameID);

                if (parsedLog.timeControl.isCorrespondence())
                    continue;

                parsedLog.append(Result(Drawish(Abort)));

                for (ref in parsedLog.playerRefs)
                    if (!Auth.isGuest(ref))
                    {
                        var data = Storage.loadPlayerData(ref);
                        if (data.getPastGamesIDs()[0] < gameID)
                            data.addPastGame(gameID, parsedLog.timeControl.getType());
                        if (data.getOngoingFiniteGame() == gameID)
                            data.removeOngoingFiniteGame();
                    }

                Logger.serviceLog("STORAGE", 'Repaired a log for a game with ID = $gameID');
            }
        }

        setServerDataField("lastRepairedLogID", lastGameID);
    }

    public static function createMissingFiles() 
    {
        for (logType in LogType.createAll())
            if (!exists(Log(logType)))
                overwrite(Log(logType), "");

        if (!exists(ServerConfig))
            overwrite(ServerConfig, "");

        if (!exists(ServerData))
            overwrite(ServerData, Json.stringify({lastGameID: 0, lastStudyID: 0, lastRepairedLogID: 0}, null, "    "));
    }

    public static function getServerDataField(fieldName:String):Int 
    {
        var data:Dynamic = Json.parse(read(ServerData));

        if (!Reflect.hasField(data, fieldName))
            throw 'Serverdata field not found: $fieldName';

        return cast(Reflect.field(data, fieldName), Int);
    }

    public static function setServerDataField(fieldName:String, value:Int)
    {
        var data:Dynamic = Json.parse(read(ServerData));

        Reflect.setField(data, fieldName, value);

        overwrite(ServerData, Json.stringify(data, null, "    "));
    }
    
    private static function filePath(file:DataFile):String 
    {
        return Path.directory(Sys.programPath()) + switch file 
        {
            case PlayerData(login): '/player/$login.json';
            case GameData(id): '/game/$id.txt';
            case StudyData(id): '/study/$id.txt';
            case Log(Event): '/logs/events.txt';
            case Log(Error): '/logs/errors.txt';
            case Log(Full): '/logs/full.txt';
            case Log(Antifraud): '/logs/antifraud.txt';
            case PasswordHashes: '/other/passwords.txt';
            case ServerConfig: '/config.yaml';
            case ServerData: '/other/serverdata.json';
        }
    }
}