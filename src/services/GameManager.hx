package services;

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
    private static var finiteTimeGamesByID:Map<Int, FiniteTimeGame> = [];
    private static var ongoingGameIDBySpectatorRef:Map<String, Int> = [];
    private static var ongoingGameIDByPlayerRef:DefaultArrayMap<String, Int> = new DefaultArrayMap([]);
    private static var correspondenceGameSpectatorsByGameID:DefaultArrayMap<Int, UserSession> = new DefaultArrayMap([]);

    private static var playerFollowersByLogin:DefaultArrayMap<String, UserSession> = new DefaultArrayMap([]);
    private static var followedPlayerLoginByFollowerRef:Map<String, String> = [];

    private static var simpleRematchParamsByGameID:Map<Int, ChallengeParams> = [];

    public static function getLastGameID():Int
    {
        return lastGameID;
    }

    public static function getGameByID(id:Int) 
    {
        //TODO: (Any game, even correspondence or past ones)
    }

    public static function getCurrentFiniteTimeGames():Array<GameInfo>
    {
        return Lambda.map(finiteTimeGamesByID, x -> x.getInfo());
    }

    public static function getFiniteTimeGameByPlayer(player:UserSession):Null<FiniteTimeGame>
    {
        var playerRef:String = player.getInteractionReference();
        var gameIDs:Array<Int> = ongoingGameIDByPlayerRef.get(playerRef);

        for (gameID in gameIDs)
        {
            var finiteTimeGame:Null<FiniteTimeGame> = finiteTimeGamesByID.get(gameID);
            if (finiteTimeGame != null)
                return finiteTimeGame;
        }
            
        return null;
    }

    public static function getOngoing(id:Int):Null<Game>
    {
        if (finiteTimeGamesByID.exists(id))
            return finiteTimeGamesByID.get(id);
        else
            return CorrespondenceGame.loadFromLog(id, onGameEnded, correspondenceGameSpectatorsByGameID.get(id));  
    }

    public static function processAction(gameID:Int, action:GameAction, issuer:UserSession) 
    {
        var game:Null<Game> = getOngoing(gameID);

        if (game == null)
            return;

        game.processAction(action, issuer);
    }

    public static function addSpectator(session:UserSession, gameID:Int, sendSpectationData:Bool) 
    {
        var spectatorRef:String = session.getInteractionReference();

        var game:Null<Game> = getOngoing(gameID);

        if (game == null)
            return;

        if (ongoingGameIDBySpectatorRef.get(spectatorRef) != gameID)
        {
            stopSpectating(session);
    
            game.sessions.addSpectator(session);
            ongoingGameIDBySpectatorRef.set(spectatorRef, gameID);

            if (game.log.timeControl.isCorrespondence())
                correspondenceGameSpectatorsByGameID.push(gameID, session);

            if (sendSpectationData)
                session.emit(SpectationData(gameID, game.getTime(), game.log.get()));
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
        
        var currentGameIDs:Array<Int> = ongoingGameIDByPlayerRef.get(followedPlayerLogin);
        for (currentGameID in currentGameIDs)
            if (ongoingGameIDBySpectatorRef.get(followerRef) != currentGameID && finiteTimeGamesByID.exists(currentGameID))
            {
                addSpectator(session, currentGameID, true);
                break;
            }
    }

    public static function stopSpectating(session:UserSession) 
    {
        var spectatorRef:String = session.getInteractionReference();

        if (!ongoingGameIDBySpectatorRef.exists(spectatorRef))
            return;

        var gameID:Int = ongoingGameIDBySpectatorRef.get(spectatorRef);
        var game:Null<Game> = getOngoing(gameID);

        if (game == null)
            return;

        game.sessions.removeSpectator(session);
        correspondenceGameSpectatorsByGameID.pop(gameID, session);
        ongoingGameIDBySpectatorRef.remove(spectatorRef);
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
        lastGameID++;

        var gameID:Int = lastGameID;

        var acceptorColor:PieceColor;

        if (params.acceptorColor != null)
            acceptorColor = params.acceptorColor;
        else
            acceptorColor = MathUtils.bernoulli(0.5)? White : Black;

        var whiteSession:UserSession = acceptorColor == White? acceptorSession : ownerSession;
        var blackSession:UserSession = acceptorColor == White? ownerSession : acceptorSession;

        stopFollowing(whiteSession);
        stopSpectating(whiteSession);
        stopFollowing(blackSession);
        stopSpectating(blackSession);

        ongoingGameIDByPlayerRef.push(whiteSession.getInteractionReference(), gameID);
        ongoingGameIDByPlayerRef.push(blackSession.getInteractionReference(), gameID);

        var logPreamble:String;

        if (params.timeControl.isCorrespondence())
        {
            var game:CorrespondenceGame = CorrespondenceGame.createNew(gameID, onGameEnded, whiteSession, blackSession, params.rated, params.customStartingSituation);
            whiteSession.storedData.addOngoingCorrespondenceGame(gameID);
            blackSession.storedData.addOngoingCorrespondenceGame(gameID);
            logPreamble = game.log.get();
        }
        else
        {
            var game:FiniteTimeGame = new FiniteTimeGame(gameID, onGameEnded, whiteSession, blackSession, params.timeControl, params.rated, params.customStartingSituation);
            finiteTimeGamesByID.set(gameID, game);
            logPreamble = game.log.get();
        }

        whiteSession.emit(GameStarted(gameID, logPreamble));
        blackSession.emit(GameStarted(gameID, logPreamble));

        for (playerLogin in [whiteSession.login, blackSession.login])
            if (playerLogin != null)
                for (follower in playerFollowersByLogin.get(playerLogin))
                {
                    follower.emit(GameStarted(gameID, logPreamble));
                    addSpectator(follower, gameID, false);
                }

        var srColor:Null<PieceColor> = params.acceptorColor != null? opposite(params.acceptorColor) : null;
        var srType:ChallengeType = Direct(acceptorSession.getInteractionReference());
        var srParams:ChallengeParams = new ChallengeParams(params.timeControl, srType, srColor, params.customStartingSituation, params.rated);
        simpleRematchParamsByGameID.set(gameID, srParams);

        return gameID;
    }

    private static function onGameEnded(outcome:Outcome, game:Game) 
    {
        var loggedPlayerData:Map<PieceColor, PlayerData> = [];
        for (color in PieceColor.createAll())
        {
            var login:Null<String> = game.log.playerLogins.get(color);
            if (login != null)
                loggedPlayerData.set(color, Storage.loadPlayerData(login));
        }

        var timeControl:TimeControlType = game.log.timeControl.getType();

        var newEloValues:Map<PieceColor, EloValue> = [];
        if (game.log.rated && !outcome.match(Drawish(Abort)))
            for (color => data in loggedPlayerData.keyValueIterator())
            {
                var formerElo:EloValue = game.log.elo[color];
                var formerOpponentElo:EloValue = game.log.elo[opposite(color)];
                var personalOutcome:PersonalOutcome = toPersonal(outcome, color);
                var priorPlayedGames:Int = data.getPlayedGamesCnt(timeControl);
                var newElo:EloValue = EloManager.recalculateElo(formerElo, formerOpponentElo, personalOutcome, priorPlayedGames);

                newEloValues.set(color, newElo);

                var login:String = game.log.playerLogins.get(color);
                Logger.addAntifraudEntry(login, "ELO_" + timeControl.getName(), EloManager.getNumericalElo(formerElo), EloManager.getNumericalElo(newElo));
            }

        for (color => data in loggedPlayerData.keyValueIterator())
            data.addPastGame(game.id, timeControl, newEloValues.get(color));
            
        var secsLeft:Map<PieceColor, Float> = [];

        if (timeControl == Correspondence)
        {
            game.sessions.getPlayerSession(White).storedData.removeOngoingCorrespondenceGame(game.id);
            game.sessions.getPlayerSession(Black).storedData.removeOngoingCorrespondenceGame(game.id);
        }
        else
        {
            secsLeft.set(White, game.log.msLeftOnOver[White] / 1000);
            secsLeft.set(Black, game.log.msLeftOnOver[Black] / 1000);
        }

        for (playerColor in PieceColor.createAll())
            game.sessions.tellPlayer(playerColor, GameEnded(outcome, secsLeft.get(White), secsLeft.get(Black), newEloValues.get(playerColor)));
        game.sessions.announceToSpectators(GameEnded(outcome, secsLeft.get(White), secsLeft.get(Black), null));

        var tenMinutesInMs:Int = 10 * 60 * 1000;
        Timer.delay(simpleRematchParamsByGameID.remove.bind(game.id), tenMinutesInMs);
    }

    public static function handleDisconnection(user:UserSession)
    {
        var userRef:String = user.getLogReference();
        
        var spectatedGameID = ongoingGameIDBySpectatorRef.get(userRef);
        if (spectatedGameID != null)
            getOngoing(spectatedGameID).handleSpectatorDisconnection(user);
        else 
            for (gameID in ongoingGameIDByPlayerRef.get(userRef))
                getOngoing(gameID).handlePlayerDisconnection(user);
    }  

    public static function handleReconnection(user:UserSession)
    {
        var userRef:String = user.getLogReference();
       
        var spectatedGameID = ongoingGameIDBySpectatorRef.get(userRef);
        if (spectatedGameID != null)
            getOngoing(spectatedGameID).handleSpectatorReconnection(user);
        else 
            for (gameID in ongoingGameIDByPlayerRef.get(userRef))
                getOngoing(gameID).handlePlayerReconnection(user);
    }

    public static function handleSessionDestruction(user:UserSession)
    {
        if (user.login != null)
            return;

        var userRef:String = user.getLogReference();
        for (gameID in ongoingGameIDByPlayerRef.get(userRef))
            getOngoing(gameID).onGuestPlayerDestroyed(user);
    }        

    public static function simpleRematch(author:UserSession, gameID:Int) 
    {
        var params:Null<ChallengeParams> = simpleRematchParamsByGameID.get(gameID);

        if (params != null)
            ChallengeManager.create(author, params);
        else
            author.emit(CreateChallengeResult(RematchExpired));
    }
}