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
    private static var pendingPublicChallengeIDs:Array<Int> = [];

    private static var pendingChallengeByID:Map<Int, Challenge> = [];

    private static var ownerLoginByFormerChallengeID:Map<Int, String> = [];
    private static var gameIDByFormerChallengeID:Map<Int, Int> = [];

    public static function getAllPendingChallenges():Array<Challenge> 
    {
        return Lambda.array(pendingChallengeByID);
    }

    public static function getPublicPendingChallenges():Array<Challenge>
    {
        return Lambda.map(pendingPublicChallengeIDs, id -> pendingChallengeByID.get(id));
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

    public static function getOpenChallenge(requestAuthor:UserSession, id:Int) 
    {
        Logger.serviceLog('CHALLENGE', '$requestAuthor requested info for challenge $id');

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
                        var isParticipant:Bool = game.log.getColorByRef(requestAuthor) != null;

                        if (isParticipant)
                            game.onPlayerJoined(requestAuthor);
                        else
                            game.onSpectatorJoined(requestAuthor);

                        requestAuthor.emit(OpenChallengeHostPlaying(OngoingGameInfo.create(game.id, game.getTime(), game.log.get())));

                        if (isParticipant)
                            game.resendPendingOffers(requestAuthor);
                    case Past(log):
                        Logger.serviceLog('CHALLENGE', 'Challenge $id has been fullfilled, the corresponding game $gameID has already ended');
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

    private static function tryMatchmaking(requestAuthor:UserSession, challenge:Challenge):Bool
    {
        for (anotherChallenge in getPublicPendingChallenges())
            if (anotherChallenge.isCompatibleWith(challenge))
            {
                Logger.serviceLog('CHALLENGE', 'Found compatible challenge ${anotherChallenge.id}, accepting it...');

                requestAuthor.emit(CreateChallengeResult(Merged));

                accept(requestAuthor, anotherChallenge.id);
                return true;
            }

        return false;
    }

    private static function performPreliminaryChecks(requestAuthor:UserSession, challenge:Challenge):Bool
    {
        var authorRef:String = requestAuthor.getReference();
        var params:ChallengeParams = challenge.params;

        if (requestAuthor.login == null)
        {
            Logger.serviceLog('CHALLENGE', 'Failed to create a challenge by $authorRef: not logged');
            requestAuthor.emit(CreateChallengeResult(Impossible));
            return false;
        }
        else if (requestAuthor.ongoingFiniteGameID != null)
        {
            Logger.serviceLog('CHALLENGE', 'Failed to create a challenge by $authorRef: busy (game ${requestAuthor.ongoingFiniteGameID})');
            requestAuthor.emit(CreateChallengeResult(Impossible));
            return false;
        }

        if (params.customStartingSituation != null)
            if (params.customStartingSituation.isDefaultStarting())
                params.customStartingSituation = null;
            else if (!params.customStartingSituation.isValidStarting())
            {
                Logger.serviceLog('CHALLENGE', 'Failed to create a challenge by $authorRef: invalid custom starting SIP: ${params.customStartingSituation.serialize()}');
                requestAuthor.emit(CreateChallengeResult(Impossible));
                return false;
            }

        if (!params.type.match(ToBot(_)))
        {
            var equivChallenge:Null<Challenge> = Lambda.find(getAllPendingChallenges(), challenge.isEquivalentTo);
            if (equivChallenge != null)
            {
                Logger.serviceLog('CHALLENGE', 'Failed to create a challenge by $authorRef: there is another equivalent pending challenge (ID: ${equivChallenge.id})');
                requestAuthor.emit(CreateChallengeResult(Duplicate));
                return false;
            }
        }

        switch params.type
        {
            case Public:
                var mergedWithOtherChallenge:Bool = tryMatchmaking(requestAuthor, challenge);
                if (mergedWithOtherChallenge)
                    return false;
            case Direct(calleeRef):
                if (requestAuthor.getReference() == calleeRef)
                {
                    Logger.serviceLog('CHALLENGE', 'Failed to create a challenge by $authorRef: caller and callee are the same person');
                    requestAuthor.emit(CreateChallengeResult(ToOneself));
                    return false;
                }
                else if (!Auth.isGuest(calleeRef) && !Auth.userExists(calleeRef))
                {
                    Logger.serviceLog('CHALLENGE', 'Failed to create a challenge by $authorRef: player not found');
                    requestAuthor.emit(CreateChallengeResult(PlayerNotFound));
                    return false;
                }
                else if (Auth.isGuest(calleeRef) && !Auth.guestSessionExists(calleeRef))
                {
                    Logger.serviceLog('CHALLENGE', 'Failed to create a challenge by $authorRef: guest not found or has already left');
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

        Logger.serviceLog('CHALLENGE', 'Challenge has passed all the preliminary checks (author: $requestAuthor)');
        return true;
    }

    public static function create(requestAuthor:UserSession, params:ChallengeParams) 
    {
        Logger.serviceLog('CHALLENGE', '$requestAuthor requested creating a new challenge');

        if (Shutdown.isStopping())
        {
            Logger.serviceLog('CHALLENGE', 'Refusing to create a challenge (server is preparing to shutdown). Requested by: $requestAuthor');
            requestAuthor.emit(CreateChallengeResult(ServerShutdown));
            return;
        }

        var id:Int = lastChallengeID + 1;
        var challenge:Challenge = new Challenge(id, params, requestAuthor.login);
        var challengeData:ChallengeData = challenge.toChallengeData();

        var creationNeeded:Bool = performPreliminaryChecks(requestAuthor, challenge);

        if (!creationNeeded)
            return;

        switch params.type 
        {
            case ToBot(botHandle):
                GameManager.startGame(challenge.params, challenge.ownerLogin, requestAuthor, VersusBot(botHandle));
                return;
            default:
        }
        
        lastChallengeID++;

        pendingChallengeByID.set(id, challenge);
        pendingChallengeIDsByOwnerLogin.push(challenge.ownerLogin, id);

        switch params.type 
        {
            case Public:
                pendingPublicChallengeIDs.push(id);
            case Direct(calleeRef):
                pendingDirectChallengeIDsByReceiverRef.push(calleeRef, id);
            default:
        }

        requestAuthor.emit(CreateChallengeResult(Success(challengeData)));

        switch params.type 
        {
            case Public:
                PageManager.notifyPageViewers(MainMenu, MainMenuNewOpenChallenge(challengeData));
                IntegrationManager.onPublicChallengeCreated(lastChallengeID, challengeData.ownerLogin, params);
            case Direct(calleeRef):
                var callee:Null<UserSession> = Auth.getUserByRef(calleeRef);
                if (callee != null)
                    callee.emit(IncomingDirectChallenge(challengeData));
            default:
        }
        
        Logger.serviceLog('CHALLENGE', 'Challenge $id has been created by ${challenge.ownerLogin}');
    }

    /**
        General purpose challenge removal: called both when a challenge is cancelled and when a challenge is fulfilled (combined via matchmaking or accepted)
    **/
    private static function removeChallenge(challenge:Challenge) 
    {
        pendingChallengeByID.remove(challenge.id);
        pendingChallengeIDsByOwnerLogin.pop(challenge.ownerLogin, challenge.id);

        switch challenge.params.type 
        {
            case Public:
                pendingPublicChallengeIDs.remove(challenge.id);
                PageManager.notifyPageViewers(MainMenu, MainMenuOpenChallengeRemoved(challenge.id));
            case Direct(calleeRef):
                pendingDirectChallengeIDsByReceiverRef.pop(calleeRef, challenge.id);
                var callee:Null<UserSession> = Auth.getUserByRef(calleeRef);
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

        Logger.serviceLog('CHALLENGE', 'Challenge ${challenge.id} is cancelled');
    }

    private static function fulfillChallenge(challenge:Challenge, ownerSession:Null<UserSession>, acceptorSession:UserSession) 
    {
        removeChallenge(challenge);
        
        var gameID:Int = GameManager.startGame(challenge.params, challenge.ownerLogin, ownerSession, VersusHuman(acceptorSession));
        gameIDByFormerChallengeID.set(challenge.id, gameID);
        ownerLoginByFormerChallengeID.set(challenge.id, challenge.ownerLogin);
        
        Logger.serviceLog('CHALLENGE', 'Challenge ${challenge.id} has been fulfilled. Acceptor: $acceptorSession. See game $gameID');
    }

    public static function accept(requestAuthor:UserSession, id:Int) 
    {
        if (Shutdown.isStopping())
        {
            Logger.serviceLog('CHALLENGE', 'Refusing to accept challenge $id (server is preparing to shutdown). Requested by: $requestAuthor');
            requestAuthor.emit(ChallengeNotAcceptedServerShutdown);
            return;
        }

        var challenge:Null<Challenge> = pendingChallengeByID.get(id);

        if (challenge == null)
        {
            var ownerLogin:Null<String> = ownerLoginByFormerChallengeID.get(id);
            var ownerSession:Null<UserSession> = ownerLogin == null? null : LoginManager.getUser(ownerLogin);

            if (ownerLogin == null)
                requestAuthor.emit(ChallengeCancelledByOwner);
            else if (ownerSession == null)
                requestAuthor.emit(ChallengeOwnerOffline(ownerLogin));
            else if (ownerSession.ongoingFiniteGameID != null)
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

        if (challenge.params.rated && requestAuthor.isGuest())
        {
            Logger.serviceLog('CHALLENGE', 'Failed to accept challenge $id: callee (${requestAuthor.login}) is guest, but the challenge is rated');
            return;
        }
        
        var ownerSession = LoginManager.getUser(challenge.ownerLogin);

        if ((!challenge.params.timeControl.isCorrespondence() || requestAuthor.isGuest()) && ownerSession == null)
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
        Logger.serviceLog('CHALLENGE', '$requestAuthor attempted to decline challenge $id');

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

        Logger.serviceLog('CHALLENGE', 'Cancelling all outgoing challenges for ${user.login}');

        var ids:Array<Int> = pendingChallengeIDsByOwnerLogin.get(user.login);

        for (id in ids)
        {
            var challenge:Null<Challenge> = pendingChallengeByID.get(id);

            if (challenge == null)
                continue;

            var isDirectToLoggedUser:Bool = switch challenge.params.type 
            {
                case Direct(calleeRef): 
                    calleeRef.charAt(0) != "_" && calleeRef.charAt(0) != "+";
                default:
                    false;
            }
            var isCorrespondence:Bool = challenge.params.timeControl.isCorrespondence();

            if (!isDirectToLoggedUser || !isCorrespondence)
                cancel(user, id);
        } 
    }

    public static function declineAllIncomingChallenges(user:UserSession)
    {
        Logger.serviceLog('CHALLENGE', 'Declining all incoming challenges for ${user.login}');

        var ids:Array<Int> = pendingDirectChallengeIDsByReceiverRef.get(user.getReference());

        for (id in ids)
            decline(user, id);
    }
    
    public static function handleSessionDestruction(user:UserSession) 
    {
        if (user.isGuest())
            declineAllIncomingChallenges(user);
        else
            cancelAllOutgoingChallenges(user);
    }

    public static function cancelAllChallenges()
    {
        Logger.serviceLog('CHALLENGE', 'Cancelling all pending challenges');

        for (challenge in pendingChallengeByID)
            removeChallenge(challenge);
    }
}