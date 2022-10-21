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

class Game 
{
    private var id:Int;
    private var log(default, set):String;

    private var playerSessions:Map<PieceColor, Null<UserSession>>;
    private var spectatorSessions:Array<UserSession> = [];

    private var moveNum:Int = 0;
    private var currentSituation:Situation;
    private var plyHistory:Array<Ply> = []; //To simplify rollbacks (caused by takebacks, for example)
    private var situationOccurences:Map<String, Int> = []; //For threefold repetition check
    private var progressiveMoveNums:Array<Int> = []; //For 60-move rule check

    private var secondsLeftOnMoveStart:Array<Map<PieceColor, Float>> = [];
    private var moveStartTimestamp:Float;

    private var hasPendingDrawRequest:Map<PieceColor, Bool> = [White => false, Black => false];
    private var hasPendingTakebackRequest:Map<PieceColor, Bool> = [White => false, Black => false];

    private var timeoutTerminationTimer:Null<Timer> = null;
    
    public function getPlayerSession(color:PieceColor):Null<UserSession> 
    {
        return playerSessions.get(color);
    }

    public function getLog() 
    {
        return log;    
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

    private function rollback(moveCnt:Int) 
    {
        hasPendingTakebackRequest = [White => false, Black => false];
        moveNum -= moveCnt;

        for (i in 0...moveCnt)
        {
            var hash:String = currentSituation.getHash();

            if (situationOccurences.exists(hash))
                if (situationOccurences[hash] > 1)
                    situationOccurences[hash]--;
                else 
                    situationOccurences.remove(hash);

            var revertedPly:Ply = plyHistory.pop();
            currentSituation.revertPly(revertedPly);

            secondsLeftOnMoveStart.pop();
        }
        
        while (progressiveMoveNums[progressiveMoveNums.length - 1] > moveNum)
            progressiveMoveNums.pop();

        var oldLogEntries:Array<String> = log.split(";").map(x -> x.trim());
        var movesAppended:Int = 0;
        var newLog:String = "";

        for (entry in oldLogEntries)
            if (entry.startsWith("#") || movesAppended < moveNum)
                newLog += entry + ";\n";

        log = newLog;

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