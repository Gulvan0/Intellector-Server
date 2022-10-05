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
        //TODO: (Any game, even correspondence or past ones)
    }

    public static function getOngoingGameByParticipantLogin(login:String):Null<Game>
    {
        return ongoingGamesByParticipantLogin.get(login);
    }

    public static function handleDisconnection(user:User) 
    {
        //TODO: Also consider the case when an user is a spectator
        
        //TODO: notify spectators and opponent (or launch termination timer if both players disconnected)
        //TODO: append event to game log
    }    
}