package stored;

import sys.ssl.Context.Config;
import services.EloManager;
import haxe.ds.Option;
import haxe.ds.Option.None as NoneOpt;
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

using utils.ds.ArrayTools;

class PlayerData
{
    private var login:String;
    private var lastMessageTimestamp:Float;
    private var pastGames:Map<Option<TimeControlType>, Array<Int>>;
    private var elo:Map<TimeControlType, EloValue>;
    private var studies:Array<Int>;
    private var ongoingCorrespondenceGames:Array<Int>;
    private var ongoingFiniteGameID:Null<Int>;
    private var roles:Array<UserRole>;
    private var friends:Array<String>;

    public static function createForNewPlayer(login:String):PlayerData 
    {
        var data:PlayerData = new PlayerData();

        data.login = login;
        data.lastMessageTimestamp = Date.now().getTime();
        data.pastGames = [NoneOpt => []];
        data.elo = [];
        data.studies = [];
        data.ongoingCorrespondenceGames = [];
        data.ongoingFiniteGameID = null;
        data.roles = [];
        data.friends = [];

        for (timeControl in TimeControlType.createAll()) 
        {
            data.pastGames.set(Some(timeControl), []);
            data.elo.set(timeControl, None);
        }

        return data;
    }

    public static function fromJSON(login:String, json:Dynamic):PlayerData
    {
        var data:PlayerData = new PlayerData();

        data.login = login;
        data.lastMessageTimestamp = json.lastMessageTimestamp;

        data.pastGames = [NoneOpt => []];

        for (timeControl in TimeControlType.createAll())
        {
            var a:Array<Int> = Reflect.field(json.games, timeControl.getName());

            data.pastGames[Some(timeControl)] = a;
            data.pastGames[NoneOpt] = data.pastGames[NoneOpt].concat(a); 
        }

        data.pastGames[NoneOpt].sortIntDesc();

        data.elo = [];

        for (timeControl in TimeControlType.createAll())
        {
            var storedValue:Null<String> = Reflect.field(json.elo, timeControl.getName());

            data.elo[timeControl] = storedValue != null? deserialize(storedValue) : None;
        }

        data.studies = json.studies;
        data.ongoingCorrespondenceGames = json.ongoingCorrespondenceGames;
        data.ongoingFiniteGameID = Reflect.field(json, "ongoingFiniteGameID");
        data.roles = Lambda.map(json.roles, x -> UserRole.createByName(x));
        data.friends = json.friends;

        return data;
    }

    public function toJSON():Dynamic
    {
        var eloObj:Dynamic = {};
        for (timeControl in TimeControlType.createAll())
            Reflect.setField(eloObj, timeControl.getName(), serialize(elo[timeControl]));

        var gamesObj:Dynamic = {};
        for (timeControl in TimeControlType.createAll())
            Reflect.setField(gamesObj, timeControl.getName(), pastGames[Some(timeControl)]);

        var json:Dynamic = {
            lastMessageTimestamp: lastMessageTimestamp,
            pastGames: gamesObj,
            elo: eloObj,
            studies: studies,
            ongoingCorrespondenceGames: ongoingCorrespondenceGames,
            roles: roles.map(x -> x.getName()),
            friends: friends
        };

        if (ongoingFiniteGameID != null)
            Reflect.setField(json, "ongoingFiniteGameID", ongoingFiniteGameID);

        return json;
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
        data.gamesCntByTimeControl = [for (timeControl in TimeControlType.createAll()) timeControl => getPlayedGamesCnt(timeControl)];
        data.isFriend = requestedByLogin != null && hasFriend(requestedByLogin);
        data.status = getStatus();

        return data;
    }

    public function toProfileData(requestedByLogin:Null<String>):ProfileData 
    {
        var data:ProfileData = new ProfileData();
        
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

        data.preloadedGames = getPastGames(0, 10);
        data.preloadedStudies = getStudies(0, 10).map;
        data.gamesInProgress = Storage.getGameInfos(ongoingCorrespondenceGames);

        if (ongoingFiniteGameID != null)
            data.gamesInProgress.unshift(Storage.getGameInfo(ongoingFiniteGameID));

        data.roles = roles;

        data.totalPastGames = getPlayedGamesCnt();
        data.totalStudies = studies.length;

        return data;
    }

    private function gameMapKey(timeControl:Null<TimeControlType>):Option<TimeControlType> 
    {
        if (timeControl == null)
            return NoneOpt;
        else
            return Some(timeControl);
    }

    public function getPastGamesIDs(?timeControl:Null<TimeControlType>):Array<Int>
    {
        return pastGames[gameMapKey(timeControl)].copy();
    }

    public function getPlayedGamesCnt(?timeControl:Null<TimeControlType>):Int
    {
        return getPastGamesIDs(timeControl).length;
    }

    public function getELO(timeControl:TimeControlType):EloValue
    {
        return elo.get(timeControl);
    }

    public function getPastGames(after:Int, pageSize:Int, ?filterByTimeControl:Null<TimeControlType>):Array<GameInfo>
    {
        var gameIDs:Array<Int> = getPastGamesIDs(filterByTimeControl).slice(after, after + pageSize);
        return Storage.getGameInfos(gameIDs);
    }

    public function getStudyIDs():Array<Int>
    {
        return studies.copy();
    }

    public function getStudies(after:Int, pageSize:Int, ?filterByTags:Array<String>):{map:Map<Int, StudyInfo>, hasNext:Bool}
    {
        var map:Map<Int, StudyInfo> = [];
        var hasNext:Bool = false;
        var seenCnt:Int = 0;
        var savedCnt:Int = 0;

        for (studyID in studies)
        {
            var data = Storage.getStudyData(studyID);
            if (filterByTags == null || data.hasTags(filterByTags))
            {
                if (seenCnt >= after)
                {
                    if (savedCnt == pageSize)
                    {
                        hasNext = true;
                        break;
                    }

                    map.set(studyID, data);
                    savedCnt++;
                }

                seenCnt++;
            }
        }

        return {map: map, hasNext: hasNext};
    }

    public function getOngoingGameIDs():Array<Int>
    {
        var a:Array<Int> = ongoingCorrespondenceGames.copy();
        
        if (ongoingFiniteGameID != null)
            a.unshift(ongoingFiniteGameID);
        
        return a;
    }

    public function addOngoingFiniteGame(gameID:Int) 
    {
        ongoingFiniteGameID = gameID;
        Storage.savePlayerData(login, this);
    }

    public function removeOngoingFiniteGame() 
    {
        ongoingFiniteGameID = null;
        Storage.savePlayerData(login, this);
    }

    public function getOngoingFiniteGame():Null<Int>
    {
        return ongoingFiniteGameID;
    }

    public function addPastGame(id:Int, timeControl:TimeControlType, ?newElo:EloValue)
    {
        pastGames[NoneOpt].unshift(id);
        pastGames[Some(timeControl)].unshift(id);

        if (newElo != null)
            elo.set(timeControl, newElo);

        Storage.savePlayerData(login, this);
    }

    public function addStudy(id:Int)
    {
        studies.unshift(id);
        Storage.savePlayerData(login, this);
    }

    public function addOngoingCorrespondenceGame(id:Int)
    {
        ongoingCorrespondenceGames.unshift(id);
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

    private function new() 
    {
        
    }
}