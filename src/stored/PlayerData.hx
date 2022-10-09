package stored;

import net.shared.EloValue;
import net.shared.TimeControlType;
import services.Storage;
import haxe.Json;

class PlayerData
{
    private var login:String;
    private var pastGames:Array<Int>;
    private var studies:Array<Int>;
    private var ongoingCorrespondenceGames:Array<Int>;
    private var friends:Array<String>;
    private var elo:Map<TimeControlType, EloValue>;
    private var gamesPlayed:Map<TimeControlType, Int>;
    private var lastMessageTimestamp:Float;

    public static function createForNewPlayer(login:String):PlayerData 
    {
        return new PlayerData(login, Date.now().getTime());
    }

    public static function fromJSON(login:String, json:Dynamic):PlayerData
    {
        var elo:Map<TimeControlType, EloValue> = [];
        var gamesPlayed:Map<TimeControlType, Int> = [];

        for (timeControl in TimeControlType.createAll())
        {
            var fieldName:String = timeControl.getName();

            if (Reflect.hasField(json.elo, fieldName))
                elo.set(timeControl, deserialize(json.elo));
            else
                elo.set(timeControl, None);

            if (Reflect.hasField(json.gamesPlayed, fieldName))
                gamesPlayed.set(timeControl, Std.parseInt(json.gamesPlayed));
            else
                gamesPlayed.set(timeControl, 0);
        }

        return new PlayerData(login, json.lastMessageTimestamp, json.pastGames, json.studies, json.ongoingCorrespondenceGames, json.friends, elo, gamesPlayed);
    }

    public function toJSON():Dynamic
    {
        return {
            pastGames: pastGames,
            studies: studies,
            ongoingCorrespondenceGames: ongoingCorrespondenceGames,
            friends: friends,
            lastMessageTimestamp: lastMessageTimestamp
        };
    }

    public function getPlayedGamesCnt(timeControl:TimeControlType):Int
    {
        return gamesPlayed.get(timeControl);
    }

    public function getELO(timeControl:TimeControlType):EloValue
    {
        return elo.get(timeControl);
    }

    public function getPastGames():Array<Int>
    {
        return pastGames.copy();
    }

    public function getStudies():Array<Int>
    {
        return studies.copy();
    }

    public function getOngoingCorrespondenceGames():Array<Int>
    {
        return ongoingCorrespondenceGames.copy();
    }

    public function addPastGame(id:Int, timeControl:TimeControlType, ?newElo:EloValue)
    {
        pastGames.push(id);

        if (gamesPlayed.exists(timeControl))
            gamesPlayed[timeControl]++;
        else
            gamesPlayed.set(timeControl, 1);

        if (newElo != null)
            elo.set(timeControl, newElo);

        Storage.savePlayerData(login, this);
    }

    public function addStudy(id:Int)
    {
        studies.push(id);
        Storage.savePlayerData(login, this);
    }

    public function addOngoingCorrespondenceGame(id:Int)
    {
        ongoingCorrespondenceGames.push(id);
        Storage.savePlayerData(login, this);
    }

    public function removeStudy(id:Int)
    {
        studies.remove(id);
        Storage.savePlayerData(login, this);
    }

    public function removeOngoingCorrespondenceGame(id:Int)
    {
        ongoingCorrespondenceGames.remove(id);
        Storage.savePlayerData(login, this);
    }

    public function getFriends():Array<String>
    {
        return friends.copy();
    }

    public function addFriend(login:String) 
    {
        friends.push(login);
    }

    public function removeFriend(login:String) 
    {
        friends.remove(login);
    }

    public function hasFriend(login:String):Bool
    {
        return friends.contains(login);
    }

    public function onMessageReceived() 
    {
        lastMessageTimestamp = Date.now().getTime();
        Storage.savePlayerData(login, this);
    }

    public function getLastMessageTimestamp():Date
    {
        return Date.fromTime(lastMessageTimestamp);
    }

    private function new(login:String, lastMessageTimestamp:Float, ?pastGames:Array<Int>, ?studies:Array<Int>, ?ongoingCorrespondenceGames:Array<Int>, ?friends:Array<String>, ?elo:Map<TimeControlType, EloValue>, ?gamesPlayed:Map<TimeControlType, Int>) 
    {
        this.login = login;
        this.pastGames = pastGames != null? pastGames : [];
        this.studies = studies != null? studies : [];
        this.ongoingCorrespondenceGames = ongoingCorrespondenceGames != null? ongoingCorrespondenceGames : [];
        this.friends = friends != null? friends : [];
        this.lastMessageTimestamp = lastMessageTimestamp;
        this.elo = elo != null? elo : [for (timeControl in TimeControlType.createAll()) timeControl => None];
        this.gamesPlayed = gamesPlayed != null? gamesPlayed : [for (timeControl in TimeControlType.createAll()) timeControl => 0];
    }
}