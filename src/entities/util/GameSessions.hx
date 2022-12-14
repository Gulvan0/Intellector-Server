package entities.util;

import net.shared.ServerEvent;
import net.shared.PieceColor;

class GameSessions 
{
    private var playerSessions:Map<PieceColor, Null<UserSession>> = [];
    private var spectatorSessions:Array<UserSession> = [];

    public function isDerelict(onlyConsiderPlayers:Bool = false):Bool
    {
        return playerSessions.get(White) == null && playerSessions.get(Black) == null && (onlyConsiderPlayers || Lambda.empty(spectatorSessions));
    }

    public function attachPlayer(color:PieceColor, session:UserSession) 
    {
        playerSessions.set(color, session);
    }

    public function playerIngame(color:PieceColor):Bool
    {
        return playerSessions.get(color) != null;
    }

    public function removePlayer(color:PieceColor) 
    {
        playerSessions.set(color, null);
    }

    public function addSpectator(session:UserSession) 
    {
        spectatorSessions.push(session);
    }

    public function spectatorIngame(session:UserSession):Bool
    {
        return Lambda.exists(spectatorSessions, x -> x.getReference() == session.getReference());
    }

    public function removeSpectator(session:UserSession) 
    {
        spectatorSessions.remove(session);
    }

    public function removeSession(session:UserSession) 
    {
        var sessionRef:String = session.getReference();

        if (playerSessions.get(White) != null && playerSessions.get(White).getReference() == sessionRef)
            removePlayer(White);
        else if (playerSessions.get(Black) != null && playerSessions.get(Black).getReference() == sessionRef)
            removePlayer(Black);
        else 
            removeSpectator(session);
    }

    public function broadcast(event:ServerEvent, ?excludedUser:Null<UserSession>)
    {
        var activePlayerSessions:Array<UserSession> = [for (session in playerSessions) if (session != null) session];
        var receivers:Array<UserSession> = activePlayerSessions.concat(spectatorSessions);
        var excludedRef:Null<String> = excludedUser != null? excludedUser.getReference() : null;

        for (session in receivers)
            if (session.getReference() != excludedRef)
                session.emit(event);
    }

    public function announceToSpectators(event:ServerEvent) 
    {
        for (session in spectatorSessions)
            session.emit(event);
    }

    public function tellPlayer(color:PieceColor, event:ServerEvent) 
    {
        var session:Null<UserSession> = playerSessions.get(color);
        if (session != null)
            session.emit(event);
    }

    public function new(players:Map<PieceColor, Null<UserSession>>) 
    {
        this.playerSessions = players;
    }
}