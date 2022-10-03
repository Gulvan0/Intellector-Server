package services;

import entities.User;

class GameManager 
{
    public static function handleDisconnection(user:User) 
    {
        if (user.ongoingGame == null) //TODO: Consider the case when an user is a spectator
            return;
        
        //TODO: notify spectators and opponent (or launch termination timer if both players disconnected)
        //TODO: append event to game log
    }    
}