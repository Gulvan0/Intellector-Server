package services;

import entities.Challenge;
import net.shared.ChallengeData;
import entities.Game;
import entities.User;

class ChallengeManager
{
    private static var lastChallengeID:Int = 0;

    private static var activeOpenChallengesByOwnerLogin:Map<String, Array<Challenge>> = [];
    private static var pendingDirectChallengesByOwnerLogin:Map<String, Array<Challenge>> = [];
    private static var pendingDirectChallengesByReceiverLogin:Map<String, Array<Challenge>> = [];
    
    private static var pendingChallengeByID:Map<Int, ChallengeData> = [];
    private static var gameIDByFormerChallengeID:Map<Int, Int> = [];

    //TODO: Getters

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
    
    public static function handleDisconnection(user:User) 
    {
        if (user.pendingOutgoingChallenges == null)
            return;

        for (id in user.pendingOutgoingChallenges)
            cancel(id);
    }
    
    public static function handleGameStart(game:Game) 
    {
        //TODO: Fill
    }
}