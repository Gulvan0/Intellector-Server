package services;

import sys.FileSystem;
import haxe.Json;
import entities.User.StoredUserData;
import integration.Telegram;
import sys.io.File;

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
}

class Storage 
{
    public static function computeLastGameID():Int 
    {
        var i:Int = 0;

        while (exists(GameData(i+1)))
            i++;
        
        return i;
    }

    public static function getGameLog(id:Int):Null<String>
    {
        if (!exists(GameData(id)))
            return null;
        else
            return read(GameData(id));
    }
    
    public static function loadPlayerData(login:String):StoredUserData
    {
        if (!exists(PlayerData(login)))
        {
            var data = new StoredUserData(login);
            savePlayerData(login, data);
            Logger.serviceLog("STORAGE", 'Created new data file for player $login');
            return data;
        }

        var content:String = read(PlayerData(login));
        var jsonData:Dynamic = Json.parse(content);
        return new StoredUserData(login, jsonData.pastGames, jsonData.studies, jsonData.ongoingCorrespondenceGames);
    }

    public static function savePlayerData(login:String, playerData:StoredUserData) 
    {
        var content:String = Json.stringify({
            pastGames: playerData.getPastGames(),
            studies: playerData.getStudies(),
            ongoingCorrespondenceGames: playerData.getOngoingCorrespondenceGames()
        }, null, "    ");
        overwrite(PlayerData(login), content);
    }

    public static function appendLog(log:LogType, entry:String) 
    {
        append(Log(log), '###${Date.now().toString()}###\n$entry\n');
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

    private static function overwrite(file:DataFile, content:String)
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
    
    private static function filePath(file:DataFile):String 
    {
        return switch file 
        {
            case PlayerData(login): './player/$login.json';
            case GameData(id): './game/$id.txt';
            case StudyData(id): './study/$id.txt';
            case Log(Event): './logs/events.txt';
            case Log(Error): './logs/errors.txt';
            case Log(Full): './logs/full.txt';
            case Log(Antifraud): './logs/antifraud.txt';
            case PasswordHashes: './other/passwords.txt';
        }
    }
}