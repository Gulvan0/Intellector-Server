package services;

import entities.Challenge;
import net.shared.ChallengeData;
import entities.Game;
import entities.User;

class ChallengeManager
{
    private static var lastChallengeID:Int = 0;

    private static var pendingChallengesByOwnerLogin:Map<String, Array<Challenge>> = [];
    private static var pendingDirectChallengesByReceiverLogin:Map<String, Array<Challenge>> = [];
    
    private static var pendingChallengeByID:Map<Int, ChallengeData> = [];
    private static var gameIDByFormerChallengeID:Map<Int, Int> = [];

    //TODO: Getters

    public static function getAllIncomingChallengesByReceiverLogin(login:String):Array<ChallengeData>
    {
        var challengeInfos:Array<ChallengeData> = [];
        var challenges:Array<Challenge> = pendingDirectChallengesByReceiverLogin.get(login);

        for (challenge in challenges)
        {
            var info:ChallengeData = new ChallengeData();
            info.id = challenge.id;
            //TODO: Fill other info fields
            challengeInfos.push(info);
        }
        
        return challengeInfos;
    }

    public static function create(data:ChallengeData) 
    {
        //TODO: Fill
    }

    public static function cancel(id:Int) 
    {
        //TODO: Fill
    } 

    public static function accept(id:Int) 
    {
        //TODO: Fill
    }

    public static function decline(id:Int) 
    {
        //TODO: Fill
    }

    private static function cancelAllOutgoingChallenges(user:User) 
    {
        if (user.login == null)
            return;

        var challengeList:Null<Array<Challenge>> = pendingChallengesByOwnerLogin.get(user.login);

        if (challengeList == null)
            return;

        for (challenge in challengeList)
            cancel(challenge.id);
    }
    
    public static function handleDisconnection(user:User) 
    {
        cancelAllOutgoingChallenges(user);
    }
    
    public static function handleGameStart(game:Game) 
    {
        cancelAllOutgoingChallenges(game.whiteUser);
        cancelAllOutgoingChallenges(game.blackUser);
    }
}