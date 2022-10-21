package entities;

import net.shared.ServerEvent;
import net.shared.PieceType;
import struct.Ply;
import struct.Situation;
import net.shared.PieceColor;
import services.Storage;

using StringTools;

abstract class Game 
{
    //TODO: Some properties should NOT be materialized for CorrespondenceGame
    private var id:Int;
    private var log(default, set):String;

    private var playerSessions:Map<PieceColor, Null<UserSession>>;
    private var spectatorSessions:Array<UserSession> = [];

    private var moveNum:Int = 0;
    private var currentSituation:Situation;
    private var plyHistory:Array<Ply> = []; //To simplify rollbacks (caused by takebacks, for example)
    private var situationOccurences:Map<String, Int> = []; //For threefold repetition check
    private var progressiveMoveNums:Array<Int> = []; //For 60-move rule check

    private var hasPendingDrawRequest:Map<PieceColor, Bool> = [White => false, Black => false];
    private var hasPendingTakebackRequest:Map<PieceColor, Bool> = [White => false, Black => false];

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

    public abstract function performPly(fromI:Int, fromJ:Int, toI:Int, toJ:Int, morphInto:Null<PieceType>):Void;
    public abstract function performTakeback(requestedBy:UserSession):Void;
    public abstract function sendMessage(author:UserSession, message:String):Void;
    private abstract function onRollback(moveCnt:Int):Void;

    public abstract function handleDisconnection(session:UserSession):Void;
    public abstract function handleReconnection(session:UserSession):Void;

    public function handleSessionDestruction(session:UserSession) 
    {
        if (playerSessions.get(White) == session)
            playerSessions.set(White, null);
        else if (playerSessions.get(Black) == session)
            playerSessions.set(Black, null);
        else
            spectatorSessions.remove(session);
    }

    private function broadcast(event:ServerEvent)
    {
        for (session in playerSessions)
            if (session != null)
                session.emit(event);
        for (session in spectatorSessions)
            session.emit(event);
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
        }
        
        while (progressiveMoveNums[progressiveMoveNums.length - 1] > moveNum)
            progressiveMoveNums.pop();

        var oldLogEntries:Array<String> = log.split(";").map(x -> x.trim());
        var movesAppended:Int = 0;
        var newLog:String = "";

        for (entry in oldLogEntries)
        {
            if (entry.startsWith("#") || movesAppended < moveNum)
                newLog += entry + ";\n";

            if (!entry.startsWith("#"))
                movesAppended++;
        }

        log = newLog;

        onRollback(moveCnt);
    }
}