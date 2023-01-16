package services;

import net.shared.dataobj.OngoingGameInfo;
import net.shared.Constants;
import services.util.SimpleAnyGame;
import entities.util.GameLog;
import utils.ds.CacheMap;
import services.util.AnyGame;
import services.util.GameMap;
import net.shared.dataobj.GameInfo;
import haxe.Timer;
import net.shared.board.PieceData;
import stored.PlayerData;
import net.shared.TimeControlType;
import net.shared.EloValue;
import utils.ds.DefaultArrayMap;
import net.GameAction;
import net.shared.Outcome;
import entities.CorrespondenceGame;
import entities.FiniteTimeGame;
import net.shared.utils.MathUtils;
import net.shared.PieceColor;
import struct.ChallengeParams;
import entities.Challenge;
import entities.Game;
import entities.UserSession;

class GameManager 
{
    private static var lastGameID:Int = Storage.getServerDataField("lastGameID");
    private static var games:GameMap = new GameMap();

    private static var playerFollowersByLogin:DefaultArrayMap<String, UserSession> = new DefaultArrayMap([]);
    private static var followedPlayerLoginByFollowerRef:Map<String, String> = [];

    private static var simpleRematchParamsByLogin:CacheMap<String, ChallengeParams> = new CacheMap([], [], 1000 * 60 * (Constants.minutesBeforeRematchExpires + 1));

    private static var onAllFiniteGamesFinished:Null<Void->Void>;

    public static function getLastGameID():Int
    {
        return lastGameID;
    }

    public static function getCurrentFiniteTimeGames():Array<GameInfo>
    {
        return games.getCurrentFiniteGames();
    }

    public static function getRecentGames():Array<GameInfo> 
    {
        var i:Int = 10;
        var currentID:Int = lastGameID;
        var infos:Array<GameInfo> = [];

        while (i > 0)
        {
            switch games.getSimple(currentID) 
            {
                case Past(log):
                    infos.push(GameInfo.create(currentID, log));
                    i--;
                default:
            }
            currentID--;
        }

		return infos;
	}

    public static function get(id:Int):AnyGame
    {
        return games.get(id);
    }

    public static function getSimple(id:Int):SimpleAnyGame
    {
        return games.getSimple(id);
    }

    public static function processAction(action:GameAction, issuer:UserSession) 
    {
        var gameID:Null<Int> = issuer.viewedGameID;

        if (gameID == null)
            return;

        switch games.getSimple(gameID) 
        {
            case Ongoing(game):
                game.processAction(action, issuer);
            default:
        }
    }

    public static function addFollower(session:UserSession, followedPlayerLogin:String) 
    {
        var followerRef:String = session.getReference();

        if (followedPlayerLogin == followedPlayerLoginByFollowerRef.get(followerRef))
            return;

        Logger.serviceLog('GAMEMGR', 'Adding $session to the list of $followedPlayerLogin\'s followers');

        stopFollowing(session);

        playerFollowersByLogin.push(followedPlayerLogin, session);
        followedPlayerLoginByFollowerRef.set(followerRef, followedPlayerLogin);
        
        var followedUser = LoginManager.getUser(followedPlayerLogin);

        if (followedUser != null)
            if (followedUser.ongoingFiniteGameID != session.viewedGameID)
            {
                switch games.getSimple(followedUser.ongoingFiniteGameID)
                {
                    case Ongoing(game):
                        game.onSpectatorJoined(session);
                        session.emit(SpectationData(OngoingGameInfo.create(game.id, game.getTime(), game.log.get())));
                    default:
                        session.emit(FollowSuccess);
                }
            }
            else
                session.emit(FollowAlreadySpectating(session.viewedGameID));
    }

    public static function stopFollowing(session:UserSession) 
    {
        var followerRef:String = session.getReference();
        var followedPlayerLogin:String = followedPlayerLoginByFollowerRef.get(followerRef);

        if (followedPlayerLogin == null)
            return;

        Logger.serviceLog('GAMEMGR', 'Removing $session from the list of $followedPlayerLogin\'s followers');
        
        playerFollowersByLogin.remove(followedPlayerLogin);
        followedPlayerLoginByFollowerRef.remove(followerRef);
    }

    public static function startGame(params:ChallengeParams, ownerSession:UserSession, acceptorSession:UserSession):Int
    {
        if (Shutdown.isStopping())
        {
            Logger.serviceLog('GAMEMGR', 'Refusing to start a new game (server is preparing to shutdown). Created by: $ownerSession, accepted by: $acceptorSession');
            return -1;
        }

        lastGameID++;
        Storage.setServerDataField("lastGameID", lastGameID);

        var gameID:Int = lastGameID;
        var acceptorColor:PieceColor = params.calculateActualAcceptorColor();

        Logger.serviceLog('GAMEMGR', 'Starting new game with ID $gameID. Created by: $ownerSession, accepted by: $acceptorSession');

        var playerSessions:Map<PieceColor, UserSession>;
        if (acceptorColor == White)
            playerSessions = [White => acceptorSession, Black => ownerSession];
        else
            playerSessions = [White => ownerSession, Black => acceptorSession];

        var game:Game = Game.create(gameID, playerSessions, params.timeControl, params.rated, params.customStartingSituation);
        var logPreamble:String = game.log.get();

        games.addNew(gameID, game);

        for (session in playerSessions)
        {
            ChallengeManager.cancelAllOutgoingChallenges(session);
            
            stopFollowing(session);

            if (params.timeControl.isCorrespondence())
                session.storedData.addOngoingCorrespondenceGame(gameID);
            else
                session.ongoingFiniteGameID = gameID;

            session.emit(GameStarted(gameID, logPreamble));

            if (session.login != null)
                for (follower in playerFollowersByLogin.get(session.login))
                {
                    game.onSpectatorJoined(follower);
                    follower.emit(GameStarted(gameID, logPreamble));
                }
        }

        PageManager.notifyPageViewers(MainMenu, MainMenuNewGame(game.getInfo()));

        Logger.serviceLog('GAMEMGR', 'Game $gameID started successfully');

        return gameID;
    }

    private static function getNewElo(color:PieceColor, data:PlayerData, outcome:Outcome, gameLog:GameLog):EloValue
    {
        var timeControlType:TimeControlType = gameLog.timeControl.getType();
        var login:String = gameLog.playerRefs.get(color);
        var formerElo:EloValue = gameLog.elo[color];
        var formerOpponentElo:EloValue = gameLog.elo[opposite(color)];
        var personalOutcome:PersonalOutcome = toPersonal(outcome, color);
        var priorRatedGames:Int = data.getRatedGamesCnt(timeControlType);
        var newElo:EloValue = EloManager.recalculateElo(formerElo, formerOpponentElo, personalOutcome, priorRatedGames);

        Logger.addAntifraudEntry(login, "ELO_" + timeControlType.getName(), EloManager.getNumericalElo(formerElo), EloManager.getNumericalElo(newElo));

        return newElo;
    }

    public static function onGameEnded(outcome:Outcome, game:Game) 
    {
        Logger.serviceLog('GAMEMGR', 'Game ${game.id} ended with outcome $outcome, performing cleanup');
        
        games.removeEnded(game.id);

        var rematchMap:Map<String, ChallengeParams> = game.getSimpleRematchParams();
        for (login => params in rematchMap.keyValueIterator())
            simpleRematchParamsByLogin.set(login, params);

        var timeControlType:TimeControlType = game.log.timeControl.getType();

        for (color in PieceColor.createAll())
        {
            var playerRef:String = game.log.playerRefs.get(color);
            var login:Null<String> = Auth.isGuest(playerRef)? null : playerRef;
            var data:Null<PlayerData> = login != null? Storage.loadPlayerData(login) : null;
            var session:Null<UserSession> = Auth.getUserByRef(playerRef);
            
            var newElo:Null<EloValue> = null;

            if (data != null)
            {
                if (game.log.rated && !outcome.match(Drawish(Abort)))
                    newElo = getNewElo(color, data, outcome, game.log);

                data.addPastGame(game.id, timeControlType, newElo);

                if (timeControlType == Correspondence)
                    data.removeOngoingCorrespondenceGame(game.id);
            }

            if (session != null)
            {
                session.ongoingFiniteGameID = null;

                var rematchPossible:Bool = login != null && rematchMap.exists(login);
                session.emit(GameEnded(outcome, rematchPossible, game.log.msLeftOnOver, newElo));
            }
        }

        game.sessions.announceToSpectators(GameEnded(outcome, false, game.log.msLeftOnOver, null));

        PageManager.notifyPageViewers(MainMenu, MainMenuGameEnded(game.getInfo()));

        if (onAllFiniteGamesFinished != null && !games.hasCurrentFiniteGames())
            onAllFiniteGamesFinished();
    }

    public static function handleDisconnection(user:UserSession)
    {
        if (user.viewedGameID != null)
            switch games.getSimple(user.viewedGameID) 
            {
                case Ongoing(game):
                    game.onPresentUserDisconnected(user);
                default:
            }
    }  

    public static function handleReconnection(user:UserSession)
    {
        if (user.viewedGameID != null)
            switch games.getSimple(user.viewedGameID) 
            {
                case Ongoing(game):
                    game.onPresentUserReconnected(user);
                default:
            }
    }

    public static function handleSessionDestruction(user:UserSession) 
    {
        stopFollowing(user);

        for (gameID in user.getRelevantGameIDs())
            switch games.getSimple(gameID) 
            {
                case Ongoing(game):
                    game.onSessionDestroyed(user);
                default:
            }
    }        

    public static function simpleRematch(author:UserSession) 
    {
        var params:Null<ChallengeParams> = simpleRematchParamsByLogin.get(author.login);

        if (params != null)
        {
            ChallengeManager.create(author, params);
            Logger.serviceLog('GAMEMGR', 'Simple rematch challenge (${params.type}) by $author');
        }
        else
            author.emit(CreateChallengeResult(RematchExpired));
    }

    public static function abortAllGames() 
    {
        Logger.serviceLog('GAMEMGR', 'Aborting all finite games...');

        for (game in games.getCurrentFiniteGames())
        {
            switch games.getSimple(game.id) 
            {
                case Ongoing(game):
                    game.abortGame();
                case Past(_):
                    Logger.logError('Game ${game.id} was found among current finite games, yet it is actually already over');
                    games.removeEnded(game.id);
                case NonExisting:
                    Logger.logError('Game ${game.id} was found among current finite games, yet it does not exist');
                    games.removeEnded(game.id);
            }
        }

        Logger.serviceLog('GAMEMGR', 'All finite games aborted');
    }

    public static function callOnAllGamesFinished(callback:Void->Void) 
    {
        if (games.hasCurrentFiniteGames())
        {
            onAllFiniteGamesFinished = callback;
            Logger.serviceLog('GAMEMGR', 'onAllFiniteGamesFinished callback has been set');
        }
        else
        {
            Logger.serviceLog('GAMEMGR', 'No finite games are in progress, invoking callback now');
            callback();
        }
    }

    public static function unloadDerelictCorrespondence(id:Int) 
    {
        games.unloadDerelictCorrespondence(id);
    }
}