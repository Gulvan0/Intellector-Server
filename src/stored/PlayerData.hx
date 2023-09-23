package stored;

import services.ProfileManager;
import services.Logger;
import sys.ssl.Context.Config;
import services.EloManager;
import haxe.ds.Option;
import haxe.ds.Option.None as NoneOpt;
import net.shared.dataobj.UserRole;
import net.shared.dataobj.StudyInfo;
import entities.FiniteTimeGame;
import net.shared.dataobj.GameInfo;
import services.GameManager;
import net.shared.dataobj.FriendData;
import net.shared.dataobj.UserStatus;
import net.shared.dataobj.ProfileData;
import entities.UserSession;
import services.LoginManager;
import net.shared.dataobj.MiniProfileData;
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
    private var ratedGamesCnt:Map<TimeControlType, Int>;
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
        data.ratedGamesCnt = [];
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
            data.ratedGamesCnt.set(timeControl, 0);
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
            var a:Array<Int> = Reflect.field(json.pastGames, timeControl.getName());

            data.pastGames[Some(timeControl)] = a;
            data.pastGames[NoneOpt] = data.pastGames[NoneOpt].concat(a); 
        }

        data.pastGames[NoneOpt].sortIntDesc();

        data.ratedGamesCnt = [];
        data.elo = [];

        for (timeControl in TimeControlType.createAll())
        {
            var storedGameCnt:Null<Int> = Reflect.field(json.ratedGamesCnt, timeControl.getName());
            var storedElo:Null<String> = Reflect.field(json.elo, timeControl.getName());

            data.ratedGamesCnt[timeControl] = storedGameCnt != null? storedGameCnt : 0;
            data.elo[timeControl] = storedElo != null? deserialize(storedElo) : None;
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

        var ratedCntObj:Dynamic = {};
        for (timeControl in TimeControlType.createAll())
            Reflect.setField(ratedCntObj, timeControl.getName(), ratedGamesCnt[timeControl]);

        var json:Dynamic = {
            lastMessageTimestamp: lastMessageTimestamp,
            pastGames: gamesObj,
            ratedGamesCnt: ratedCntObj,
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

        if (user == null || user.connection == null || user.login == null)
            return Offline(Math.round((Date.now().getTime() - lastMessageTimestamp) / 1000));
        else if (user.ongoingFiniteGameID != null)
            return InGame;
        else
            return Online;
    }

    public function toMiniProfileData(author:UserSession):MiniProfileData
    {
        var data:MiniProfileData = new MiniProfileData();

        data.elo = elo;
        data.gamesCntByTimeControl = [for (timeControl in TimeControlType.createAll()) timeControl => getPlayedGamesCnt(timeControl)];
        data.isFriend = author.login != null && ProfileManager.isFriend(author, login);
        data.status = getStatus();

        return data;
    }

    public function toProfileData(author:UserSession):ProfileData 
    {
        var data:ProfileData = new ProfileData();
        
        var miniData:MiniProfileData = toMiniProfileData(author);
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

    public function getRatedGamesCnt(timeControl:TimeControlType):Int
    {
        return ratedGamesCnt[timeControl];
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
            var data:StudyData = Storage.getStudyData(studyID);
            if (filterByTags == null || data.hasTags(filterByTags))
            {
                if (seenCnt >= after)
                {
                    if (savedCnt == pageSize)
                    {
                        hasNext = true;
                        break;
                    }

                    map.set(studyID, data.toStudyInfo());
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
        if (ongoingFiniteGameID == gameID)
            return;

        ongoingFiniteGameID = gameID;
        Logger.serviceLog('PLAYERDATA', 'Game $gameID added to the $login\'s list of ongoing finite games');
        Storage.savePlayerData(login, this);
    }

    public function removeOngoingFiniteGame() 
    {
        if (ongoingFiniteGameID == null)
            return;

        Logger.serviceLog('PLAYERDATA', 'Game $ongoingFiniteGameID removed from the $login\'s list of ongoing finite games');
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
        {
            ratedGamesCnt[timeControl]++;
            elo[timeControl] = newElo;
        }

        Logger.serviceLog('PLAYERDATA', 'Game $id added to the $login\'s list of past games');

        Storage.savePlayerData(login, this);
    }

    public function addStudy(id:Int)
    {
        studies.unshift(id);
        Logger.serviceLog('PLAYERDATA', 'Study $id added to the $login\'s list of studies');
        Storage.savePlayerData(login, this);
    }

    public function addOngoingCorrespondenceGame(id:Int, ?checkExists:Bool = false)
    {
        if (checkExists && ongoingCorrespondenceGames.contains(id))
            return;
        
        ongoingCorrespondenceGames.unshift(id);
        Logger.serviceLog('PLAYERDATA', 'Game $id added to the $login\'s list of ongoing correspondence games');
        Storage.savePlayerData(login, this);
    }

    public function removeStudy(id:Int)
    {
        studies.remove(id);
        Logger.serviceLog('PLAYERDATA', 'Study $id removed from the $login\'s list of studies');
        Storage.savePlayerData(login, this);
    }

    public function removeOngoingCorrespondenceGame(id:Int)
    {
        ongoingCorrespondenceGames.remove(id);
        Logger.serviceLog('PLAYERDATA', 'Game $id removed from the $login\'s list of ongoing correspondence games');
        Storage.savePlayerData(login, this);
    }

    public function getFriends():Array<String>
    {
        return friends.copy();
    }

    public function addFriend(friendLogin:String) 
    {
        if (!hasFriend(friendLogin))
            friends.push(friendLogin);
        Storage.savePlayerData(login, this);
    }

    public function removeFriend(friendLogin:String) 
    {
        friends.remove(friendLogin);
        Storage.savePlayerData(login, this);
    }

    public function getRoles():Array<UserRole>
    {
        return roles.copy();
    }

    public function addRole(role:UserRole) 
    {
        if (!roles.contains(role))
            roles.push(role);
        Storage.savePlayerData(login, this);
    }

    public function removeRole(role:UserRole) 
    {
        roles.remove(role);
        Storage.savePlayerData(login, this);
    }

    public function hasFriend(friendLogin:String):Bool
    {
        return friends.contains(friendLogin);
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

    public function resetGames()
    {
        pastGames = [NoneOpt => []];
        ratedGamesCnt = [];
        elo = [];
        ongoingCorrespondenceGames = [];
        ongoingFiniteGameID = null;

        for (timeControl in TimeControlType.createAll()) 
        {
            pastGames.set(Some(timeControl), []);
            elo.set(timeControl, None);
            ratedGamesCnt.set(timeControl, 0);
        }

        Storage.savePlayerData(login, this);
    }

    private function new() 
    {
        
    }
}