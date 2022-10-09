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

    private static var pendingChallengeIDsByOwnerLogin:DefaultArrayMap<String, Int> = new DefaultArrayMap();
    private static var pendingDirectChallengeIDsByReceiverLogin:DefaultArrayMap<String, Int> = new DefaultArrayMap();
    
    private static var pendingPublicChallengeByIndicator:Map<String, Challenge> = [];

    private static var pendingChallengeByID:Map<Int, Challenge> = [];
    private static var gameIDByFormerChallengeID:Map<Int, Int> = [];

    //TODO: Getters

    public static function getAllIncomingChallengesByReceiverLogin(login:String):Array<ChallengeData>
    {
        var challengeInfos:Array<ChallengeData> = [];
        var ids:Array<Int> = pendingDirectChallengeIDsByReceiverLogin.get(login);
        var challenges:Array<Challenge> = [for (id in ids) pendingChallengeByID.get(id)];

        for (challenge in challenges)
        {
            if (challenge == null)
                continue;

            var info:ChallengeData = new ChallengeData();
            info.id = challenge.id;
            info.serializedParams = challenge.params.serialize();
            info.ownerLogin = challenge.ownerLogin;
            info.ownerELO = Storage.loadPlayerData(login).getELO(challenge.params.timeControl.getType());
            challengeInfos.push(info);
        }
        
        return challengeInfos;
    }

    public static function create(requestAuthor:UserSession, params:ChallengeParams) 
    {
        if (requestAuthor.getState() != Browsing)
            return;

        if (params.type == Public)
            for (compatibleIndicator in params.compatibleIndicators())
            {
                var compatibleChallenge:Null<Challenge> = pendingPublicChallengeByIndicator.get(compatibleIndicator);
                if (compatibleChallenge != null)
                {
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
    } 

    public static function accept(requestAuthor:UserSession, id:Int) 
    {
        var challenge:Null<Challenge> = pendingChallengeByID.get(id);
        
        if (requestAuthor.login == null)
            if (challenge == null || challenge.params.type.match(Direct(_)))
                return;
            else
            {
                //TODO: Accept open challenge as guest??
            }

        var ownerSession = LoginManager.getUser(challenge.ownerLogin);
        var gameID = gameIDByFormerChallengeID.get(id);

        if (challenge != null && ownerSession != null)
        {
            //TODO: Accept challenge
        }
        else if (challenge != null)
        {
            removeChallenge(challenge);
            requestAuthor.emit(OpenchallengeNotFound);
            Logger.logError('Challenge ${challenge.id} is present, but the owner (${challenge.ownerLogin}) is offline');
        }
        else if (gameID != null && GameManager.getOngoingGameByID(gameID) != null)
        {
            //TODO: Send game data
        }
        else
            requestAuthor.emit(OpenchallengeNotFound); //TODO: Or maybe use other event?
    }

    public static function decline(requestAuthor:UserSession, id:Int) 
    {
        //TODO: Fill
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