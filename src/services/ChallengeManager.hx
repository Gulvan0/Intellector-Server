package services;

import utils.ds.DefaultArrayMap;
import stored.PlayerData;
import struct.ChallengeParams;
import net.shared.PieceColor;
import entities.Challenge;
import net.shared.ChallengeData;
import entities.Game;
import entities.UserSession;

class ChallengeManager
{
    private static var lastChallengeID:Int = 0;

    private static var pendingChallengeIDsByOwnerLogin:DefaultArrayMap<String, Int> = new DefaultArrayMap([]);
    private static var pendingDirectChallengeIDsByReceiverLogin:DefaultArrayMap<String, Int> = new DefaultArrayMap([]);
    
    private static var pendingPublicChallengeByIndicator:Map<String, Challenge> = [];

    private static var pendingChallengeByID:Map<Int, Challenge> = [];

    private static var ownerLoginByFormerChallengeID:Map<Int, String> = [];
    private static var gameIDByFormerChallengeID:Map<Int, Int> = [];

    public static function getAllIncomingChallengesByReceiverLogin(login:String):Array<ChallengeData>
    {
        var challengeInfos:Array<ChallengeData> = [];
        var ids:Array<Int> = pendingDirectChallengeIDsByReceiverLogin.get(login);
        var challenges:Array<Challenge> = [for (id in ids) pendingChallengeByID.get(id)];

        for (challenge in challenges)
            if (challenge != null)
                challengeInfos.push(challenge.toChallengeData());

        return challengeInfos;
    }

    public static function getOpenChallenge(requestAuthor:UserSession, id:Int) 
    {
        Logger.serviceLog('CHALLENGE', '${requestAuthor.getLogReference()} requested info for challenge $id');

        var challenge:Null<Challenge> = pendingChallengeByID.get(id);
        if (challenge == null)
        {
            var gameID:Null<Int> = gameIDByFormerChallengeID.get(id);
            var game:Null<Game> = gameID != null? GameManager.getFiniteTimeGameByID(gameID) : null;
            
            if (game != null)
            {
                Logger.serviceLog('CHALLENGE', 'Challenge $id has been fullfilled, the corresponding game is still in progress');
                requestAuthor.emit(OpenChallengeHostPlaying(gameID, game.getTimeData(), game.getLog()));
                game.addSpectator(requestAuthor);
            }
            else
            {
                Logger.serviceLog('CHALLENGE', 'Challenge $id does not exist');
                requestAuthor.emit(OpenChallengeNotFound);
            }
        }
        else if (challenge.isDirect())
        {
            Logger.serviceLog('CHALLENGE', 'Challenge $id is direct');
            requestAuthor.emit(OpenChallengeNotFound);
        }
        else if (requestAuthor.login == null && challenge.params.timeControl.getType() == Correspondence)
        {
            Logger.serviceLog('CHALLENGE', 'Challenge $id has correspondence time control, but the player requesting it is anonymous');
            requestAuthor.emit(OpenChallengeNotFound);
        }
        else
        {
            Logger.serviceLog('CHALLENGE', 'Challenge $id was found successfully');
            requestAuthor.emit(OpenChallengeInfo(challenge.toChallengeData()));
        }
    }

    public static function create(requestAuthor:UserSession, params:ChallengeParams) 
    {
        Logger.serviceLog('CHALLENGE', '${requestAuthor.getLogReference()} requested creating a new challenge');

        if (requestAuthor.getState() != Browsing)
            return;

        if (params.type == Public)
            for (compatibleIndicator in params.compatibleIndicators())
            {
                var compatibleChallenge:Null<Challenge> = pendingPublicChallengeByIndicator.get(compatibleIndicator);
                if (compatibleChallenge != null)
                {
                    Logger.serviceLog('CHALLENGE', 'Found compatible challenge ${compatibleChallenge.id}, accepting it...');
                    pendingPublicChallengeByIndicator.remove(compatibleIndicator);
                    accept(requestAuthor, compatibleChallenge.id);
                    return;
                }
            }
        
        lastChallengeID++;

        var challenge:Challenge = new Challenge(lastChallengeID, params, requestAuthor.login);

        pendingChallengeByID.set(challenge.id, challenge);

        pendingChallengeIDsByOwnerLogin.push(challenge.ownerLogin, challenge.id);

        switch params.type 
        {
            case Public:
                pendingPublicChallengeByIndicator.set(params.compatibilityIndicator(), challenge);
            case Direct(calleeLogin):
                pendingDirectChallengeIDsByReceiverLogin.push(calleeLogin, challenge.id);
            default:
        }

        Logger.serviceLog('CHALLENGE', 'Challenge ${challenge.id} has been created by ${challenge.ownerLogin}');
    }

    private static function removeChallenge(challenge:Challenge) 
    {
        pendingChallengeByID.remove(challenge.id);
        pendingChallengeIDsByOwnerLogin.pop(challenge.ownerLogin, challenge.id);

        switch challenge.params.type 
        {
            case Public:
                pendingPublicChallengeByIndicator.remove(challenge.params.compatibilityIndicator());
            case Direct(calleeLogin):
                pendingDirectChallengeIDsByReceiverLogin.pop(calleeLogin, challenge.id);
            default:
        }
    }

    public static function cancel(requestAuthor:UserSession, id:Int) 
    {
        var challenge:Null<Challenge> = pendingChallengeByID.get(id);

        if (challenge == null || requestAuthor.login == null || challenge.ownerLogin != requestAuthor.login)
            return;

        removeChallenge(challenge);

        Logger.serviceLog('CHALLENGE', 'Challenge ${challenge.id} is cancelled by its owner');
    }

    private static function fulfillChallenge(challenge:Challenge, ownerSession:UserSession, acceptorSession:UserSession) 
    {
        removeChallenge(challenge);
        
        var gameID:Int = GameManager.startGame(challenge.params, ownerSession, acceptorSession);
        gameIDByFormerChallengeID.set(challenge.id, gameID);
        ownerLoginByFormerChallengeID.set(challenge.id, challenge.ownerLogin);
        
        Logger.serviceLog('CHALLENGE', 'Challenge ${challenge.id} has been fulfilled. Acceptor: ${acceptorSession.getLogReference()}. See game $gameID');
    }

    public static function accept(requestAuthor:UserSession, id:Int) 
    {
        var challenge:Null<Challenge> = pendingChallengeByID.get(id);

        if (challenge == null)
        {
            var ownerLogin:Null<String> = ownerLoginByFormerChallengeID.get(id);
            var ownerSession:Null<UserSession> = ownerLogin == null? null : LoginManager.getUser(ownerLogin);

            if (ownerLogin == null)
                requestAuthor.emit(ChallengeCancelledByOwner);
            else if (ownerSession == null)
                requestAuthor.emit(ChallengeOwnerOffline(ownerLogin));
            else if (ownerSession.getState() == InGame)
                requestAuthor.emit(ChallengeOwnerInGame(ownerLogin));
            else
                requestAuthor.emit(ChallengeCancelledByOwner);

            Logger.serviceLog('CHALLENGE', 'Failed to accept challenge $id: challenge not found');
            return;
        }
        
        var ownerSession = LoginManager.getUser(challenge.ownerLogin);

        if (ownerSession == null)
        {
            removeChallenge(challenge);
            requestAuthor.emit(ChallengeOwnerOffline(challenge.ownerLogin));
            Logger.logError('Challenge ${challenge.id} is present, but the owner (${challenge.ownerLogin}) is offline');
        }
        else if (requestAuthor.login == null && challenge.isDirect())
            Logger.serviceLog('CHALLENGE', 'Anonymous user ${requestAuthor.getLogReference()} attempted to accept a direct challenge ${challenge.id}. Refusing');
        else if (requestAuthor.login == null && challenge.params.timeControl.getType() == Correspondence)
            Logger.serviceLog('CHALLENGE', 'Anonymous user ${requestAuthor.getLogReference()} attempted to accept a challenge ${challenge.id} having correspondence time control. Refusing');
        else 
            fulfillChallenge(challenge, ownerSession, requestAuthor);
    }

    public static function decline(requestAuthor:UserSession, id:Int) 
    {
        Logger.serviceLog('CHALLENGE', '${requestAuthor.getLogReference()} attempted to decline challenge $id');

        var challenge:Null<Challenge> = pendingChallengeByID.get(id);

        if (challenge == null)
        {
            Logger.serviceLog('CHALLENGE', 'Failed to decline challenge $id: challenge not found');
            return;
        }

        removeChallenge(challenge);

        var ownerSession = LoginManager.getUser(challenge.ownerLogin);

        if (ownerSession != null)
            ownerSession.emit(DirectChallengeDeclined(id));
    }

    private static function cancelAllOutgoingChallenges(user:UserSession)
    {
        if (user.login == null)
            return;

        var ids:Array<Int> = pendingChallengeIDsByOwnerLogin.get(user.login);

        for (id in ids)
            cancel(user, id);
    }
    
    public static function handleDisconnection(user:UserSession) 
    {
        cancelAllOutgoingChallenges(user);
    }
    
    public static function handleGameStart(game:Game) 
    {
        for (color in PieceColor.createAll())
        {
            var session:Null<UserSession> = game.getPlayerSession(color);
            if (session != null)
                cancelAllOutgoingChallenges(session);
        }
    }
}