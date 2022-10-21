package entities;

import net.shared.TimeReservesData;
import net.shared.PieceType;
import haxe.Timer;
import net.shared.PieceColor;
import net.shared.ServerEvent;
import struct.Situation;
import struct.Ply;
import struct.TimeControl;
import services.Storage;

using StringTools;

class FiniteTimeGame extends Game 
{
    private var secondsLeftOnMoveStart:Array<Map<PieceColor, Float>> = [];
    private var moveStartTimestamp:Float;

    private var timeoutTerminationTimer:Null<Timer> = null;

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

    public function getTimeData():TimeReservesData
    {
        var secsLeft = secondsLeftOnMoveStart[moveNum];
        return new TimeReservesData(secsLeft.get(White), secsLeft.get(Black), moveStartTimestamp);
    }

    private function broadcastTimeData()
    {
        broadcast(TimeCorrection(getTimeData()));
    }

    public function checkTime() 
    {
        //TODO: Fill
    }

    private function onRollback(moveCnt:Int) 
    {
        for (i in 0...moveCnt)
            secondsLeftOnMoveStart.pop();

        moveStartTimestamp = Date.now().getTime();
        broadcastTimeData();
    }

    public function performPly(fromI:Int, fromJ:Int, toI:Int, toJ:Int, morphInto:Null<PieceType>) 
    {
        //TODO: Fill
    }

    public function performTakeback(requestedBy:UserSession) 
    {
        //TODO: Fill
    }

    public function sendMessage(author:UserSession, message:String) 
    {
        if (playerSessions.get(White) == author || playerSessions.get(Black) == author)
            broadcast(Message(author.login, message));
        else
            for (spectator in spectatorSessions)
                spectator.emit(SpectatorMessage(author.login, message));
    }

    //TODO: Fill

    public function new(id:Int, whitePlayer:UserSession, blackPlayer:UserSession, timeControl:TimeControl, ?customStartingSituation:Situation)
    {
        //TODO: Fill
    }
}