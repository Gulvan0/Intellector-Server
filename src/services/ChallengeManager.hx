package services;

import entities.Game;
import entities.User;

class ChallengeManager
{
    private static var lastChallengeID:Int;

    public static function create() 
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