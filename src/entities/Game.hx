package entities;

import haxe.Timer;
import net.shared.PieceColor;
import net.shared.ServerEvent;
import struct.Situation;
import struct.Ply;
import struct.TimeControl;
import services.Storage;

class Game 
{
    private var id:Int;
    private var log(default, set):String;

    private var playerLogins:Map<PieceColor, String>;

    private var playerSessions:Map<PieceColor, Null<UserSession>>;
    private var spectatorSessions:Array<UserSession> = [];

    private var moveNum:Int = 0;
    private var currentSituation:Situation;
    private var plyHistory:Array<Ply> = []; //To simplify rollbacks (caused by takebacks, for example)
    private var situationOccurences:Map<String, Int> = []; //For threefold repetition check
    private var progressiveMoveNums:Array<Int> = []; //For 60-move rule check

    private var secondsLeftOnMoveStart:Array<Map<PieceColor, Float>> = [];
    private var moveStartTimestamp:Array<Float> = [];

    private var timeoutTerminationTimer:Null<Timer> = null;
    
    public function getPlayerSession(color:PieceColor):Null<UserSession> 
    {
        return playerSessions.get(color);
    }

    private function set_log(value:String):String 
    {
        log = value;
        Storage.overwrite(GameData(id), log);
        return log;
    }

    private function broadcast(event:ServerEvent)
    {
        for (session in playerSessions)
            if (session != null)
                session.emit(event);
        for (session in spectatorSessions)
            session.emit(event);
    }

    public function handleDisconnection(session:UserSession) 
    {
        if (playerSessions.get(White) == session)
            broadcast(PlayerDisconnected(White));
        else if (playerSessions.get(Black) == session)
            broadcast(PlayerDisconnected(Black));
        else
            broadcast(SpectatorLeft(session.login));
    }

    public function handleReconnection(session:UserSession) 
    {
        if (playerSessions.get(White) == session)
            broadcast(PlayerReconnected(White));
        else if (playerSessions.get(Black) == session)
            broadcast(PlayerReconnected(Black));
        else
            broadcast(NewSpectator(session.login));
    }

    public function handleSessionDestruction(session:UserSession) 
    {
        if (playerSessions.get(White) == session)
            playerSessions.set(White, null);
        else if (playerSessions.get(Black) == session)
            playerSessions.set(Black, null);
        else
            spectatorSessions.remove(session);
    }

    public function addSpectator(session:UserSession) 
    {
        broadcast(NewSpectator(session.login));
        spectatorSessions.push(session);
    }

    public function removeSpectator(session:UserSession) 
    {
        spectatorSessions.remove(session);
        broadcast(SpectatorLeft(session.login));
    }

    //TODO: Fill

    public function new(id:Int, whitePlayer:UserSession, blackPlayer:UserSession, timeControl:TimeControl, ?customStartingSituation:Situation)
    {
        //TODO: Fill
    }
}