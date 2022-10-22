package entities.util;

import net.shared.ServerEvent;
import net.shared.PieceColor;

class GameSessions 
{
    private var playerSessions:Map<PieceColor, Null<UserSession>> = [];
    private var spectatorSessions:Array<UserSession> = [];

    private var broadcastConnectionEvents:Bool = true;

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

    public function broadcast(event:ServerEvent)
    {
        tellPlayer(White, event);
        tellPlayer(Black, event);
        announceToSpectators(event);
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
            playerSessions.set(White, null);
        else if (playerSessions.get(Black) == session)
            playerSessions.set(Black, null);
        else
            spectatorSessions.remove(session);
    }

    public function new(broadcastConnectionEvents:Bool, whiteSession:UserSession, blackSession:UserSession) 
    {
        this.broadcastConnectionEvents = broadcastConnectionEvents;
        this.playerSessions = [White => whiteSession, Black => blackSession];
    }
}