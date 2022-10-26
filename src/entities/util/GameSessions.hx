package entities.util;

import net.shared.ServerEvent;
import net.shared.PieceColor;

class GameSessions 
{
    private var playerSessions:Map<PieceColor, Null<UserSession>> = [];
    private var spectatorSessions:Array<UserSession> = [];

    private var broadcastConnectionEvents:Bool = true;

    public function getPlayerColor(player:UserSession):Null<PieceColor>
    {
        for (color in PieceColor.createAll())
            if (playerSessions.get(color).getInteractionReference() == player.getInteractionReference())
                return color;
        return null;
    }

    public function getPlayerSession(color:PieceColor):Null<UserSession> 
    {
        return playerSessions.get(color);
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
        if (broadcastConnectionEvents)
            broadcast(NewSpectator(session.login));
        spectatorSessions.push(session);
    }

    public function removeSpectator(session:UserSession) 
    {
        spectatorSessions.remove(session);
        if (broadcastConnectionEvents)
            broadcast(SpectatorLeft(session.login));
    }

    public function broadcast(event:ServerEvent, ?excludedUser:Null<UserSession>)
    {
        var excludedColor:Null<PieceColor> = excludedUser != null? getPlayerColor(excludedUser) : null;

        for (color in PieceColor.createAll())
            if (color != excludedColor)
                tellPlayer(color, event);

        for (session in spectatorSessions)
            if (session != excludedUser)
                session.emit(event);
    }

    public function announceToSpectators(event:ServerEvent) 
    {
        for (session in spectatorSessions)
            session.emit(event);
    }

    public function tellPlayer(color:PieceColor, event:ServerEvent) 
    {
        var session:UserSession = getPlayerSession(color);
        if (session != null)
            session.emit(event);
    }

    public function onSessionDestroyed(session:UserSession) 
    {
        if (playerSessions.get(White) == session)
            removePlayer(White);
        else if (playerSessions.get(Black) == session)
            removePlayer(Black);
        else
            spectatorSessions.remove(session);
    }

    public function new(broadcastConnectionEvents:Bool, whiteSession:Null<UserSession>, blackSession:Null<UserSession>, ?existingSpectators:Array<UserSession>) 
    {
        this.broadcastConnectionEvents = broadcastConnectionEvents;
        this.playerSessions = [White => whiteSession, Black => blackSession];
        if (existingSpectators != null)
            this.spectatorSessions = existingSpectators;
    }
}