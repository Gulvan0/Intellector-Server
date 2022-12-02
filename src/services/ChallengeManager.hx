package services;

import net.shared.dataobj.OngoingGameInfo;
import integration.Vk;
import integration.Discord;
import utils.ds.DefaultArrayMap;
import stored.PlayerData;
import struct.ChallengeParams;
import net.shared.PieceColor;
import entities.Challenge;
import net.shared.dataobj.ChallengeData;
import entities.Game;
import entities.UserSession;

using utils.ds.ArrayTools;

class ChallengeManager
{
    private static var lastChallengeID:Int = 0;

    private static var pendingChallengeIDsByOwnerLogin:DefaultArrayMap<String, Int> = new DefaultArrayMap([]);
    private static var pendingDirectChallengeIDsByReceiverRef:DefaultArrayMap<String, Int> = new DefaultArrayMap([]);
    
    private static var pendingPublicChallengeByIndicator:Map<String, Challenge> = [];
    private static var pendingChallengeIDByUniqIndicator:Map<String, Int> = [];

    private static var pendingChallengeByID:Map<Int, Challenge> = [];

    private static var ownerLoginByFormerChallengeID:Map<Int, String> = [];
    private static var gameIDByFormerChallengeID:Map<Int, Int> = [];

    public static function getAllPendingChallenges():Array<Challenge> 
    {
        return Lambda.array(pendingChallengeByID);
    }

    public static function getAllIncomingChallengesByReceiverLogin(login:String):Array<ChallengeData>
    {
        var challengeInfos:Array<ChallengeData> = [];
        var ids:Array<Int> = pendingDirectChallengeIDsByReceiverRef.get(login);
        var challenges:Array<Challenge> = [for (id in ids) pendingChallengeByID.get(id)];

        for (challenge in challenges)
            if (challenge != null)
                challengeInfos.push(challenge.toChallengeData());

        return challengeInfos;
    }

    public static function getPublicChallenges():Array<ChallengeData>
    {
        return Lambda.map(pendingPublicChallengeByIndicator, x -> x.toChallengeData());
    }

    public static function getOpenChallenge(requestAuthor:UserSession, id:Int) 
    {
        Logger.serviceLog('CHALLENGE', '${requestAuthor.getLogReference()} requested info for challenge $id');

        var challenge:Null<Challenge> = pendingChallengeByID.get(id);
        if (challenge == null)
        {
            var gameID:Null<Int> = gameIDByFormerChallengeID.get(id);

            if (gameID == null)
            {
                Logger.serviceLog('CHALLENGE', 'Challenge $id does not exist');
                requestAuthor.emit(OpenChallengeNotFound);
            }
            else
                switch GameManager.getSimple(gameID) 
                {
                    case Ongoing(game):
                        Logger.serviceLog('CHALLENGE', 'Challenge $id has been fullfilled, the corresponding game $gameID is still in progress');
                        requestAuthor.emit(OpenChallengeHostPlaying(OngoingGameInfo.create(game.id, game.getTime(), game.log.get())));
                        GameManager.addSpectator(requestAuthor, gameID, false);
                    case Past(log):
                        Logger.serviceLog('CHALLENGE', 'Challenge $id has been fullfilled, the corresponding game $gameID has already ended');
                        requestAuthor.viewedGameID = gameID;
                        requestAuthor.emit(OpenChallengeGameEnded(gameID, log));
                    case NonExisting:
                        Logger.serviceLog('CHALLENGE', 'Challenge $id is linked to gameID = $gameID, but there\'s no game with such id');
                        requestAuthor.emit(OpenChallengeNotFound);
                }
        }
        else if (challenge.isDirect())
        {
            Logger.serviceLog('CHALLENGE', 'Challenge $id is direct');
            requestAuthor.emit(OpenChallengeNotFound);
        }
        else
        {
            Logger.serviceLog('CHALLENGE', 'Challenge $id was found successfully');
            requestAuthor.emit(OpenChallengeInfo(challenge.toChallengeData()));
        }
    }

    private static function tryMatchmaking(requestAuthor:UserSession, compatibleIndicators:Array<String>):Bool
    {
        for (compatibleIndicator in compatibleIndicators)
        {
            var compatibleChallenge:Null<Challenge> = pendingPublicChallengeByIndicator.get(compatibleIndicator);
            if (compatibleChallenge != null)
            {
                requestAuthor.emit(CreateChallengeResult(Merged));

                Logger.serviceLog('CHALLENGE', 'Found compatible challenge ${compatibleChallenge.id}, accepting it...');
                pendingPublicChallengeByIndicator.remove(compatibleIndicator);
                accept(requestAuthor, compatibleChallenge.id);
                return true;
            }
        }
        return false;
    }

    private static function performPreliminaryChecks(requestAuthor:UserSession, challengeType:ChallengeType, compatibleIndicators:Array<String>, uniqIndicator:String):Bool
    {
        var authorRef:String = requestAuthor.getLogReference();

        if (requestAuthor.getState() != Browsing)
        {
            Logger.serviceLog('CHALLENGE', 'Failed to create a challenge by $authorRef: user state ${requestAuthor.getState()} != Browsing');
            requestAuthor.emit(CreateChallengeResult(Impossible));
            return false;
        }

        if (pendingChallengeIDByUniqIndicator.exists(uniqIndicator))
        {
            var anotherChallengeID:Int = pendingChallengeIDByUniqIndicator.get(uniqIndicator);
            Logger.serviceLog('CHALLENGE', 'Failed to create a challenge by $authorRef: there is another pending challenge (ID: $anotherChallengeID) with the same indicator $uniqIndicator');
            requestAuthor.emit(CreateChallengeResult(Duplicate));
            return false;
        }

        switch challengeType
        {
            case Public:
                var mergedWithOtherChallenge:Bool = tryMatchmaking(requestAuthor, compatibleIndicators);
                if (mergedWithOtherChallenge)
                    return false;
            case Direct(calleeRef):
                if (requestAuthor.getInteractionReference() == calleeRef)
                {
                    Logger.serviceLog('CHALLENGE', 'Failed to create a challenge by $authorRef: caller and callee are the same person');
                    requestAuthor.emit(CreateChallengeResult(ToOneself));
                    return false;
                }
                else if (!Auth.isGuest(calleeRef) && !Auth.userExists(calleeRef))
                {
                    Logger.serviceLog('CHALLENGE', 'Failed to create a challenge by $authorRef: callee not found');
                    requestAuthor.emit(CreateChallengeResult(PlayerNotFound));
                    return false;
                }
                else if (pendingChallengeIDsByOwnerLogin.get(requestAuthor.login).intersects(pendingDirectChallengeIDsByReceiverRef.get(calleeRef)))
                {
                    Logger.serviceLog('CHALLENGE', 'Failed to create a challenge by $authorRef: another challenge with the same caller and callee already exists');
                    requestAuthor.emit(CreateChallengeResult(AlreadyExists));
                    return false;
                }
            default:
        }

        Logger.serviceLog('CHALLENGE', 'Challenge has passed all the preliminary checks (author: ${requestAuthor.getLogReference()})');
        return true;
    }

    public static function create(requestAuthor:UserSession, params:ChallengeParams) 
    {
        Logger.serviceLog('CHALLENGE', '${requestAuthor.getLogReference()} requested creating a new challenge');

        var challenge:Challenge = new Challenge(lastChallengeID + 1, params, requestAuthor.login);

        var creationNeeded:Bool = performPreliminaryChecks(requestAuthor, params.type, params.compatibleIndicators(), challenge.equivalenceIndicator());
        if (!creationNeeded)
            return;
        
        lastChallengeID++;

        pendingChallengeByID.set(challenge.id, challenge);

        pendingChallengeIDsByOwnerLogin.push(challenge.ownerLogin, challenge.id);
        pendingChallengeIDByUniqIndicator.set(challenge.equivalenceIndicator(), challenge.id);

        switch params.type 
        {
            case Public:
                pendingPublicChallengeByIndicator.set(params.compatibilityIndicator(), challenge);
            case Direct(calleeRef):
                pendingDirectChallengeIDsByReceiverRef.push(calleeRef, challenge.id);
            default:
        }

        var challengeData:ChallengeData = new ChallengeData();
        challengeData.id = lastChallengeID;
        challengeData.ownerELO = requestAuthor.storedData.getELO(params.timeControl.getType());
        challengeData.ownerLogin = requestAuthor.login;
        challengeData.serializedParams = params.serialize();
        requestAuthor.emit(CreateChallengeResult(Success(challengeData)));

        switch params.type 
        {
            case Public:
                SpecialBroadcaster.broadcast(MainMenu, MainMenuNewOpenChallenge(challengeData));
                IntegrationManager.onPublicChallengeCreated(lastChallengeID, challengeData.ownerLogin, params);
            case Direct(calleeRef):
                var callee:Null<UserSession> = Auth.getUserByInteractionReference(calleeRef);
                if (callee != null)
                    callee.emit(IncomingDirectChallenge(challengeData));
            default:
        }
        
        Logger.serviceLog('CHALLENGE', 'Challenge ${challenge.id} has been created by ${challenge.ownerLogin}');
    }

    /**
        General purpose challenge removal: called both when a challenge is cancelled and when a challenge is fulfilled (combined via matchmaking or accepted)
    **/
    private static function removeChallenge(challenge:Challenge) 
    {
        pendingChallengeByID.remove(challenge.id);
        pendingChallengeIDsByOwnerLogin.pop(challenge.ownerLogin, challenge.id);
        pendingChallengeIDByUniqIndicator.remove(challenge.equivalenceIndicator());

        switch challenge.params.type 
        {
            case Public:
                pendingPublicChallengeByIndicator.remove(challenge.params.compatibilityIndicator());
                SpecialBroadcaster.broadcast(MainMenu, MainMenuOpenChallengeRemoved(challenge.id));
            case Direct(calleeRef):
                pendingDirectChallengeIDsByReceiverRef.pop(calleeRef, challenge.id);
                var callee:Null<UserSession> = Auth.getUserByInteractionReference(calleeRef);
                if (callee != null)
                    callee.emit(DirectChallengeCancelled(challenge.id));
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
            else if (ownerSession.getState().match(PlayingFiniteGame(_)))
                requestAuthor.emit(ChallengeOwnerInGame(ownerLogin));
            else
                requestAuthor.emit(ChallengeCancelledByOwner);

            Logger.serviceLog('CHALLENGE', 'Failed to accept challenge $id: challenge not found');
            return;
        }

        if (challenge.ownerLogin == requestAuthor.login)
        {
            Logger.serviceLog('CHALLENGE', 'Failed to accept challenge $id: caller = callee (${requestAuthor.login})');
            return;
        }
        
        var ownerSession = LoginManager.getUser(challenge.ownerLogin);

        if (ownerSession == null)
        {
            removeChallenge(challenge);
            requestAuthor.emit(ChallengeOwnerOffline(challenge.ownerLogin));
            Logger.logError('Challenge ${challenge.id} is present, but the owner (${challenge.ownerLogin}) is offline');
        }
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

    public static function cancelAllOutgoingChallenges(user:UserSession)
    {
        if (user.login == null)
            return;

        Logger.serviceLog('CHALLENGE', 'Cancelling all challenges for ${user.login}');

        var ids:Array<Int> = pendingChallengeIDsByOwnerLogin.get(user.login);

        for (id in ids)
            cancel(user, id);
    }
    
    public static function handleDisconnection(user:UserSession) 
    {
        cancelAllOutgoingChallenges(user);
    }
}