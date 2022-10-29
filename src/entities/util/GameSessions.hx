package entities.util;

import net.shared.ServerEvent;
import net.shared.PieceColor;

class GameSessions 
{
    private var playerSessions:Map<PieceColor, Null<UserSession>> = [];
    private var spectatorSessions:Array<UserSession> = [];

    public function getSpectators():Array<UserSession> 
    {
        return spectatorSessions.copy();    
    }

    public function getPresentPlayerColor(player:UserSession):Null<PieceColor>
    {
        for (color in PieceColor.createAll())
            if (playerSessions.get(color).getInteractionReference() == player.getInteractionReference())
                return color;
        return null;
    }

    public function getPresentPlayerSession(color:PieceColor):Null<UserSession> 
    {
        return playerSessions.get(color);
    }

    public function isDerelict():Bool
    {
        return playerSessions.get(White) == null && playerSessions.get(Black) == null && Lambda.empty(spectatorSessions);
    }

    public function attachPlayer(color:PieceColor, session:UserSession) 
    {
        playerSessions.set(color, session);
    }

    public function removePlayer(color:PieceColor) 
    {
        playerSessions.set(color, null);
    }

    public function addSpectator(session:UserSession) 
    {
        spectatorSessions.push(session);
    }

    public function removeSpectator(session:UserSession) 
    {
        spectatorSessions.remove(session);
    }

    public function removeSession(session:UserSession) 
    {
        var sessionRef:String = session.getInteractionReference();

        if (playerSessions.get(White).getInteractionReference() == sessionRef)
            removePlayer(White);
        else if (playerSessions.get(Black).getInteractionReference() == sessionRef)
            removePlayer(Black);
        else 
            removeSpectator(session);
    }

    public function broadcast(event:ServerEvent, ?excludedUser:Null<UserSession>)
    {
        var receivers:Array<UserSession> = [for (session in playerSessions) session].concat(spectatorSessions);
        var excludedRef:Null<String> = excludedUser != null? excludedUser.getInteractionReference() : null;

        for (session in receivers)
            if (session.getInteractionReference() != excludedRef)
                session.emit(event);
    }

    public function announceToSpectators(event:ServerEvent) 
    {
        for (session in spectatorSessions)
            session.emit(event);
    }

    public function tellPlayer(color:PieceColor, event:ServerEvent) 
    {
        var session:UserSession = getPresentPlayerSession(color);
        if (session != null)
            session.emit(event);
    }

    public function new(players:Map<PieceColor, Null<UserSession>>) 
    {
        this.playerSessions = players;
    }
}