package services;

import utils.MathUtils;
import net.shared.PieceColor;
import struct.ChallengeParams;
import entities.Challenge;
import entities.Game;
import entities.UserSession;

class GameManager 
{
    private static var lastGameID:Int = Storage.computeLastGameID();
    private static var ongoingGamesByID:Map<Int, Game> = [];
    private static var ongoingGamesByParticipantLogin:Map<String, Game> = [];

    //TODO: Add getters

    public static function startGame(params:ChallengeParams, ownerSession:UserSession, acceptorSession:UserSession):Int
    {
        lastGameID++;

        var acceptorColor:PieceColor;

        if (params.acceptorColor != null)
            acceptorColor = params.acceptorColor;
        else
            acceptorColor = MathUtils.bernoulli(0.5)? White : Black;

        var whiteSession:UserSession = acceptorColor == White? acceptorSession : ownerSession;
        var blackSession:UserSession = acceptorColor == White? ownerSession : acceptorSession;

        var game:Game = new Game(lastGameID, whiteSession, blackSession, params.timeControl, params.customStartingSituation);
        ongoingGamesByID.set(lastGameID, game);
        ongoingGamesByParticipantLogin.set(whiteSession.getInteractionReference(), game);
        ongoingGamesByParticipantLogin.set(blackSession.getInteractionReference(), game);

        var currentLog:String = game.getLog();
        whiteSession.emit(GameStarted(lastGameID, currentLog));
        blackSession.emit(GameStarted(lastGameID, currentLog));

        //TODO: Notify followers and make them spectators

        return lastGameID;
    }

    public static function getGameByID(id:Int) 
    {
        //TODO: (Any game, even correspondence or past ones)
    }

    public static function getOngoingGameByID(id:Int):Null<Game>
    {
        return ongoingGamesByID.get(id);
    }

    public static function getOngoingGameByParticipantLogin(login:String):Null<Game>
    {
        return ongoingGamesByParticipantLogin.get(login);
    }

    public static function handleDisconnection(user:UserSession)
    {
        //TODO: Also consider the case when an user is a spectator
        
        //TODO: notify spectators and opponent (or launch termination timer if both players disconnected)
        //TODO: append event to game log
    }    
}