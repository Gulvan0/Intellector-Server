package services;

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
    private static var lastGameID:Int = Storage.computeLastGameID();
    private static var finiteTimeGamesByID:Map<Int, FiniteTimeGame> = [];
    private static var ongoingGameIDBySpectatorRef:Map<String, Int> = [];
    private static var finiteTimeGameIDByPlayerRef:Map<String, Int> = [];

    private static var playerFollowersByLogin:DefaultArrayMap<String, UserSession> = new DefaultArrayMap([]);
    private static var followedPlayerLoginByFollowerRef:Map<String, String> = [];

    public static function getGameByID(id:Int) 
    {
        //TODO: (Any game, even correspondence or past ones)
    }

    public static function getFiniteTimeGameByPlayer(player:UserSession):Null<FiniteTimeGame>
    {
        var playerRef:String = player.getInteractionReference();
        var gameID:Null<Int> = finiteTimeGameIDByPlayerRef.get(playerRef);
        return gameID != null? finiteTimeGamesByID.get(gameID) : null;
    }

    private static function getOngoing(id:Int):Null<Game>
    {
        if (finiteTimeGamesByID.exists(id))
            return finiteTimeGamesByID.get(id);
        else
            return CorrespondenceGame.loadFromLog(id);  
    }

    public static function processAction(gameID:Int, action:GameAction, issuer:UserSession) 
    {
        var game:Null<Game> = getOngoing(gameID);

        if (game == null)
            return;

        game.processAction(action, issuer);
    }

    private static function addSpectator(session:UserSession, gameID:Int, sendSpectationData:Bool) 
    {
        var game:Null<Game> = getOngoing(gameID);

        if (game == null)
            return;

        stopSpectating(session);

        game.sessions.addSpectator(session);
        ongoingGameIDBySpectatorRef.set(session.getInteractionReference(), gameID);

        if (sendSpectationData)
            session.emit(SpectationData(gameID, game.time.getTime(), game.log.get()));
    }

    public static function addFollower(session:UserSession, followedPlayerLogin:String) 
    {
        stopFollowing(session);

        playerFollowersByLogin.push(followedPlayerLogin, session);
        
        var followerRef:String = session.getInteractionReference();
        var currentGameID:Null<Int> = finiteTimeGameIDByPlayerRef.get(followedPlayerLogin);
        if (currentGameID != null && ongoingGameIDBySpectatorRef.get(followerRef) != currentGameID)
            addSpectator(session, currentGameID, true);
    }

    public static function stopSpectating(session:UserSession) 
    {
        var spectatorRef:String = session.getInteractionReference();

        if (!ongoingGameIDBySpectatorRef.exists(spectatorRef))
            return;

        var game:Game = getOngoing(ongoingGameIDBySpectatorRef.get(spectatorRef));
        game.sessions.removeSpectator(session);
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

        var game:Game;

        stopFollowing(whiteSession);
        stopSpectating(whiteSession);
        stopFollowing(blackSession);
        stopSpectating(blackSession);

        finiteTimeGameIDByPlayerRef.set(whiteSession.getInteractionReference(), gameID);
        finiteTimeGameIDByPlayerRef.set(blackSession.getInteractionReference(), gameID);

        var logPreamble:String;

        if (params.timeControl.isCorrespondence())
        {
            var game:CorrespondenceGame = CorrespondenceGame.createNew(gameID, whiteSession, blackSession, params.customStartingSituation);
            logPreamble = game.log.get();
        }
        else
        {
            var game:FiniteTimeGame = new FiniteTimeGame(gameID, whiteSession, blackSession, params.timeControl, params.customStartingSituation);
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

        return gameID;
    }

    public static function onGameEnded(id:Int, outcome:Outcome) 
    {
        //TODO: Fill
    }

    public static function handleDisconnection(user:UserSession)
    {
        //TODO: Also consider the case when an user is a spectator
        
        //TODO: notify spectators and opponent (or launch termination timer if both players disconnected)
        //TODO: append event to game log
    }    
}