package services;

import net.shared.Outcome;
import entities.CorrespondenceGame;
import entities.FiniteTimeGame;
import utils.MathUtils;
import net.shared.PieceColor;
import struct.ChallengeParams;
import entities.Challenge;
import entities.Game;
import entities.UserSession;

class GameManager 
{
    private static var lastGameID:Int = Storage.computeLastGameID();
    private static var finiteTimeGamesByID:Map<Int, FiniteTimeGame> = [];
    private static var ongoingGamesByParticipantLogin:Map<String, Game> = [];

    //TODO: Add getters

    public static function getGameByID(id:Int) 
    {
        //TODO: (Any game, even correspondence or past ones)
    }

    public static function getFiniteTimeGameByID(id:Int):Null<FiniteTimeGame>
    {
        return finiteTimeGamesByID.get(id);
    }

    public static function getOngoingGameByParticipant(login:String):Null<Game>
    {
        return ongoingGamesByParticipantLogin.get(login);
    }

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

        var game:Game;

        if (params.timeControl.getType() == Correspondence)
        {
            //TODO: Create new correspondence game
        }
        else
        {
            var finiteTimeGame:FiniteTimeGame = new FiniteTimeGame(lastGameID, whiteSession, blackSession, params.timeControl, params.customStartingSituation);
            finiteTimeGamesByID.set(lastGameID, finiteTimeGame);
            game = finiteTimeGame;
        }

        ongoingGamesByParticipantLogin.set(whiteSession.getInteractionReference(), game);
        ongoingGamesByParticipantLogin.set(blackSession.getInteractionReference(), game);

        var currentLog:String = game.getLog();
        whiteSession.emit(GameStarted(lastGameID, currentLog));
        blackSession.emit(GameStarted(lastGameID, currentLog));

        for (playerLogin in [whiteSession.login, blackSession.login])
            if (playerLogin != null)
                for (follower in SpectatorManager.getFollowers(playerLogin))
                {
                    follower.emit(GameStarted(lastGameID, currentLog));
                    game.addSpectator(follower);
                }

        return lastGameID;
    }

    public static function onGameEnded(id:Int, outcome:Outcome) 
    {
        //TODO: Fill
    }

    public static function handleDisconnection(user:UserSession)
    {
        //TODO: Also consider the case when an user is a spectator
        
        //TODO: notify spectators and opponent (or launch termination timer if both players disconnected)
        //TODO: append event to game log
    }    
}