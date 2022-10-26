package services;

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

    public static function getStudyData(id:Int):Null<StudyData>
    {
        if (!exists(StudyData(id)))
            return null;

        var contentStr:String = read(StudyData(id));
        var contentJSON:Dynamic = Json.parse(contentStr);
        var contentData:StudyData = stored.StudyData.fromJSON(contentJSON);
        return contentData;
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
    }

    public static function appendLog(log:LogType, entry:String) 
    {
        append(Log(log), '\n### ${Date.now().toString()} ###\n\n$entry\n');
    }

    public static function exists(file:DataFile):Bool
    {
        return FileSystem.exists(filePath(file));
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
        var gameID:Int = getServerDataField("lastRepairedLogID") + 1;

        while (gameID <= lastGameID)
        {
            var log:String = getGameLog(gameID);

            if (!log.contains("#R|"))
            {
                var parsedLog = GameLog.load(gameID);

                if (parsedLog.timeControl.isCorrespondence())
                    continue;

                parsedLog.append(Result(Drawish(Abort)));

                for (login in parsedLog.playerLogins)
                    if (login != null)
                    {
                        var data = Storage.loadPlayerData(login);
                        if (data.getPastGamesIDs()[0] < gameID)
                            data.addPastGame(gameID, parsedLog.timeControl.getType());
                    }
            }

            gameID++;
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