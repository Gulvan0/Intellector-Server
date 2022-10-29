package services;

import services.util.SimpleAnyGame;
import entities.util.GameLog;
import utils.ds.CacheMap;
import services.util.AnyGame;
import services.util.GameMap;
import net.shared.GameInfo;
import haxe.Timer;
import struct.Piece;
import stored.PlayerData;
import net.shared.TimeControlType;
import net.shared.EloValue;
import utils.ds.DefaultArrayMap;
import net.GameAction;
import net.shared.Outcome;
import entities.CorrespondenceGame;
import entities.FiniteTimeGame;
import utils.MathUtils;
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

    private static var simpleRematchParamsByLogin:CacheMap<String, ChallengeParams> = new CacheMap([], [], 1000 * 60 * 11);

    public static function getLastGameID():Int
    {
        return lastGameID;
    }

    public static function getCurrentFiniteTimeGames():Array<GameInfo>
    {
        return games.getCurrentFiniteGames();
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

    public static function addSpectator(session:UserSession, gameID:Int, sendSpectationData:Bool) 
    {
        if (gameID == session.viewedGameID || session.ongoingFiniteGameID != null)
            return;

        switch games.getSimple(gameID) 
        {
            case Ongoing(game):
                leaveGame(session);
                session.viewedGameID = gameID;
                game.onSpectatorJoined(session);
                if (sendSpectationData)
                    session.emit(SpectationData(gameID, game.getTime(), game.log.get()));
            default:
        }
    }

    public static function addFollower(session:UserSession, followedPlayerLogin:String) 
    {
        var followerRef:String = session.getInteractionReference();

        if (followedPlayerLogin == followedPlayerLoginByFollowerRef.get(followerRef))
            return;

        stopFollowing(session);

        playerFollowersByLogin.push(followedPlayerLogin, session);
        followedPlayerLoginByFollowerRef.set(followerRef, followedPlayerLogin);
        
        var followedUser = LoginManager.getUser(followedPlayerLogin);

        if (followedUser != null && followedUser.ongoingFiniteGameID != session.viewedGameID)
            addSpectator(session, followedUser.ongoingFiniteGameID, true);
    }

    public static function stopFollowing(session:UserSession) 
    {
        var followerRef:String = session.getInteractionReference();

        if (!followedPlayerLoginByFollowerRef.exists(followerRef))
            return;
        
        playerFollowersByLogin.remove(followedPlayerLoginByFollowerRef.get(followerRef));
        followedPlayerLoginByFollowerRef.remove(followerRef);
    }

    public static function startGame(params:ChallengeParams, ownerSession:UserSession, acceptorSession:UserSession):Int
    {
        var gameID:Int = ++lastGameID;
        var acceptorColor:PieceColor = params.calculateActualAcceptorColor();

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
            leaveGame(session);
            session.viewedGameID = gameID;
            if (params.timeControl.isCorrespondence())
                session.storedData.addOngoingCorrespondenceGame(gameID);
            else
                session.ongoingFiniteGameID = gameID;

            session.emit(GameStarted(gameID, logPreamble));

            if (session.login != null)
                for (follower in playerFollowersByLogin.get(session.login))
                {
                    follower.emit(GameStarted(gameID, logPreamble));
                    addSpectator(follower, gameID, false);
                }
        }

        return gameID;
    }

    private static function getNewElo(color:PieceColor, data:PlayerData, outcome:Outcome, gameLog:GameLog):EloValue
    {
        var timeControlType:TimeControlType = gameLog.timeControl.getType();
        var login:String = gameLog.playerLogins.get(color);
        var formerElo:EloValue = gameLog.elo[color];
        var formerOpponentElo:EloValue = gameLog.elo[opposite(color)];
        var personalOutcome:PersonalOutcome = toPersonal(outcome, color);
        var priorPlayedGames:Int = data.getPlayedGamesCnt(timeControlType);
        var newElo:EloValue = EloManager.recalculateElo(formerElo, formerOpponentElo, personalOutcome, priorPlayedGames);

        Logger.addAntifraudEntry(login, "ELO_" + timeControlType.getName(), EloManager.getNumericalElo(formerElo), EloManager.getNumericalElo(newElo));

        return newElo;
    }

    public static function onGameEnded(outcome:Outcome, game:Game) 
    {
        games.removeEnded(game.id);

        var rematchMap:Map<String, ChallengeParams> = game.getSimpleRematchParams();
        for (login => params in rematchMap.keyValueIterator())
            simpleRematchParamsByLogin.set(login, params);

        var timeControlType:TimeControlType = game.log.timeControl.getType();

        for (color in PieceColor.createAll())
        {
            var login:Null<String> = game.log.playerLogins.get(color);
            var data:Null<PlayerData> = login != null? Storage.loadPlayerData(login) : null;
            var session:Null<UserSession> = game.sessions.getPresentPlayerSession(color);
            
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
        for (gameID in user.getRelevantGameIDs())
            switch games.get(gameID) 
            {
                case OngoingFinite(game):
                    game.onSessionDestroyed(user);
                case OngoingCorrespondence(game):
                    game.onSessionDestroyed(user);
                    if (game.sessions.isDerelict())
                        games.unloadDerelictCorrespondence(gameID);
                default:
            }
    }        

    public static function simpleRematch(author:UserSession) 
    {
        var params:Null<ChallengeParams> = simpleRematchParamsByLogin.get(author.login);

        if (params != null)
            ChallengeManager.create(author, params);
        else
            author.emit(CreateChallengeResult(RematchExpired));
    }

    public static function leaveGame(user:UserSession) 
    {
        if (user.viewedGameID == null)
            return;

        switch games.get(user.viewedGameID) 
        {
            case OngoingFinite(game):
                game.onUserLeft(user);
            case OngoingCorrespondence(game):
                game.onUserLeft(user);
                if (game.sessions.isDerelict())
                    games.unloadDerelictCorrespondence(user.viewedGameID);
            default:
        }

        user.viewedGameID = null;
    }
}