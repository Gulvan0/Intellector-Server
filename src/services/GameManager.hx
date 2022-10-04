package services;

import entities.Game;
import entities.User;

class GameManager 
{
    private static var lastGameID:Int = Storage.computeLastGameID();
    private static var ongoingGamesByID:Map<Int, Game> = [];
    private static var ongoingGamesByParticipantLogin:Map<String, Game> = [];
    private static var ongoingGamesBySpectatorLogin:Map<String, Game> = [];

    //TODO: Add getters

    public static function getGameByID() 
    {
        //(Any game)
    }

    public static function handleDisconnection(user:User) 
    {
        if (user.ongoingGame == null) //TODO: Consider the case when an user is a spectator
            return;
        
        //TODO: notify spectators and opponent (or launch termination timer if both players disconnected)
        //TODO: append event to game log
    }    
}