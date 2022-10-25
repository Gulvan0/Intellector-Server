package stored;

import net.shared.UserRole;
import net.shared.StudyInfo;
import entities.FiniteTimeGame;
import net.shared.GameInfo;
import services.GameManager;
import net.shared.FriendData;
import net.shared.UserStatus;
import net.shared.ProfileData;
import entities.UserSession;
import services.LoginManager;
import net.shared.MiniProfileData;
import net.shared.EloValue;
import net.shared.TimeControlType;
import services.Storage;
import haxe.Json;

class PlayerData
{
    private var login:String;
    private var roles:Array<UserRole>;
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

        var lastMessageTimestamp:Float = Date.now().getTime();
        if (Reflect.hasField(json, "lastMessageTimestamp"))
            lastMessageTimestamp = json.lastMessageTimestamp;

        var pastGames:Array<Int> = [];
        if (Reflect.hasField(json, "pastGames"))
            pastGames = json.pastGames;
        else if (Reflect.hasField(json, "games"))
            pastGames = json.games;

        var studies:Array<Int> = [];
        if (Reflect.hasField(json, "studies"))
            studies = json.studies;

        var ongoingCorrespondenceGames:Array<Int> = [];
        if (Reflect.hasField(json, "ongoingCorrespondenceGames"))
            ongoingCorrespondenceGames = json.ongoingCorrespondenceGames;

        var friends:Array<String> = [];
        if (Reflect.hasField(json, "friends"))
            friends = json.friends;

        var roles:Array<UserRole> = [];
        if (Reflect.hasField(json, "roles"))
            roles = Lambda.map(json.roles, x -> UserRole.createByName(x));

        return new PlayerData(login, lastMessageTimestamp, pastGames, studies, ongoingCorrespondenceGames, friends, elo, gamesPlayed, roles);
    }

    public function toJSON():Dynamic
    {
        return {
            pastGames: pastGames,
            roles: roles.map(x -> x.getName()),
            studies: studies,
            ongoingCorrespondenceGames: ongoingCorrespondenceGames,
            friends: friends,
            lastMessageTimestamp: lastMessageTimestamp
        };
    }

    public function getStatus():UserStatus
    {
        var user:Null<UserSession> = LoginManager.getUser(login);

        if (user == null || user.getState() == AwaitingReconnection || user.getState() == NotLogged)
            return Offline(Math.round((Date.now().getTime() - lastMessageTimestamp) / 1000));
        else if (user.getState() == Browsing)
            return Online;
        else
            return InGame;
    }

    public function toMiniProfileData(requestedByLogin:Null<String>):MiniProfileData
    {
        var data:MiniProfileData = new MiniProfileData();

        data.elo = elo;
        data.gamesCntByTimeControl = gamesPlayed;
        data.isFriend = requestedByLogin != null && hasFriend(requestedByLogin);
        data.status = getStatus();

        return data;
    }

    public function toProfileData(requestedByLogin:Null<String>):ProfileData 
    {
        var data:ProfileData = new ProfileData();

        var user:Null<UserSession> = LoginManager.getUser(login);
        
        var miniData:MiniProfileData = toMiniProfileData(requestedByLogin);
        data.elo = miniData.elo;
        data.gamesCntByTimeControl = miniData.gamesCntByTimeControl;
        data.isFriend = miniData.isFriend;
        data.status = miniData.status;

        data.friends = [];
        for (friendLogin in friends)
        {
            var playerData:PlayerData = Storage.loadPlayerData(friendLogin);
            var friendData:FriendData = {login: friendLogin, status: playerData.getStatus()};
    
            data.friends.push(friendData);
        }

        data.gamesInProgress = [];
        
        if (user != null)
        {
            var finiteTimeGame:Null<FiniteTimeGame> = GameManager.getFiniteTimeGameByPlayer(user);

            if (finiteTimeGame != null)
                data.gamesInProgress.push(finiteTimeGame.getInfo());
        }

        for (gameID in ongoingCorrespondenceGames)
            data.gamesInProgress.push(GameManager.getOngoing(gameID).getInfo());
        
        data.preloadedGames = [];
        for (gameID in pastGames.slice(-10))
        {
            var info:GameInfo = new GameInfo();
            info.id = gameID;
            info.log = Storage.getGameLog(gameID);
            data.preloadedGames.push(info);
        }

        data.preloadedStudies = [];
        for (studyID in studies.slice(-10))
        {
            var info:StudyInfo = new StudyInfo(); //TODO: Replace with actual info retrieval
            data.preloadedStudies.set(studyID, info);
        }

        data.roles = roles;

        data.totalPastGames = pastGames.length;
        data.totalStudies = studies.length;

        return data;
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
        if (!hasFriend(login))
            friends.push(login);
        Storage.savePlayerData(login, this);
    }

    public function removeFriend(login:String) 
    {
        friends.remove(login);
        Storage.savePlayerData(login, this);
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

    private function new(login:String, lastMessageTimestamp:Float, ?pastGames:Array<Int>, ?studies:Array<Int>, ?ongoingCorrespondenceGames:Array<Int>, ?friends:Array<String>, ?elo:Map<TimeControlType, EloValue>, ?gamesPlayed:Map<TimeControlType, Int>, ?roles:Array<UserRole>) 
    {
        this.login = login;
        this.pastGames = pastGames != null? pastGames : [];
        this.studies = studies != null? studies : [];
        this.ongoingCorrespondenceGames = ongoingCorrespondenceGames != null? ongoingCorrespondenceGames : [];
        this.friends = friends != null? friends : [];
        this.lastMessageTimestamp = lastMessageTimestamp;
        this.elo = elo != null? elo : [for (timeControl in TimeControlType.createAll()) timeControl => None];
        this.gamesPlayed = gamesPlayed != null? gamesPlayed : [for (timeControl in TimeControlType.createAll()) timeControl => 0];
        this.roles = roles != null? roles : [];
    }
}