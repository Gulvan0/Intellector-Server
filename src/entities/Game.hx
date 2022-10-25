package entities;

import net.shared.TimeReservesData;
import services.EloManager;
import entities.util.GameTime.IGameTime;
import net.shared.Outcome;
import net.GameAction;
import net.shared.TimeReservesData;
import entities.util.GameLog;
import entities.util.GameState;
import entities.util.GameSessions;
import entities.util.GameOffers;
import services.GameManager;
import utils.ds.DefaultCountMap;
import struct.HexCoords;
import net.shared.ServerEvent;
import net.shared.PieceType;
import struct.Ply;
import struct.Situation;
import net.shared.PieceColor;
import services.Storage;

using StringTools;

class Game 
{
    public final id:Int;

    public var log:GameLog;
    public var offers:GameOffers;
    public var sessions:GameSessions;
    public var state:GameState;
    public var time:IGameTime;

    private var onEndedCallback:Outcome->Game->Void;

    public function getTime():Null<TimeReservesData> 
    {
        return time.getTime(state.turnColor(), state.moveNum);
    }

    private function onMoveSuccessful(author:UserSession, turnColor:PieceColor, moveNum:Int, from:HexCoords, to:HexCoords, morphInto:Null<PieceType>) 
    {
        time.onMoveMade(turnColor, moveNum);

        var msAtMoveStart = time.getMsAtMoveStart();
        var whiteMs = msAtMoveStart != null? msAtMoveStart.get(White) : null;
        var blackMs = msAtMoveStart != null? msAtMoveStart.get(Black) : null;

        var actualTimeData = getTime();

        log.append(Move(from, to, morphInto, whiteMs, blackMs));
        offers.onMoveMade();
        sessions.broadcast(Move(from.i, to.i, from.j, to.j, morphInto, actualTimeData), author);
        if (actualTimeData != null)
            sessions.tellPlayer(turnColor, TimeCorrection(actualTimeData));
    }

    private function performMove(author:UserSession, fromI:Int, toI:Int, fromJ:Int, toJ:Int, morphInto:Null<PieceType>) 
    {
        var turnColor:PieceColor = state.turnColor();
        var from:HexCoords = new HexCoords(fromI, fromJ);
        var to:HexCoords = new HexCoords(toI, toJ);
        var result:TryPlyResult = state.tryPly(from, to, morphInto);

        switch result 
        {
            case Performed:
                onMoveSuccessful(author, turnColor, state.moveNum - 1, from, to, morphInto);
            case GameEnded(outcome):
                onMoveSuccessful(author, turnColor, state.moveNum - 1, from, to, morphInto);
                endGame(outcome);
            case Failed:
                sessions.tellPlayer(turnColor, InvalidMove);
        }
    }

    private function sendMessage(author:UserSession, text:String) 
    {
        var authorColor:Null<PieceColor> = sessions.getPlayerColor(author);
        if (authorColor != null)
        {
            log.append(PlayerMessage(authorColor, text));
            sessions.broadcast(Message(author.login, text), author);
        }
        else
            sessions.broadcast(SpectatorMessage(author.login, text), author);
    }

    private function endGame(outcome:Outcome) 
    {
        time.stopTime(state.turnColor(), state.moveNum);
        var finalTime:Null<TimeReservesData> = getTime();

        log.append(Result(outcome));
        if (finalTime != null)
        {
            var whiteMsLeft:Int = Math.floor(finalTime.whiteSeconds * 1000);
            var blackMsLeft:Int = Math.floor(finalTime.blackSeconds * 1000);
            log.append(MsLeft(whiteMsLeft, blackMsLeft));
        }

        onEndedCallback(outcome, this);
    }

    private function rollback(requestedBy:PieceColor) 
    {
        var moveCnt:Int = requestedBy == state.turnColor()? 2 : 1;

        log.rollback(moveCnt);
        state.rollback(moveCnt);
        time.onRollback(moveCnt, state.turnColor(), state.moveNum);
        sessions.broadcast(Rollback(moveCnt, getTime()));
    }

    public function processAction(action:GameAction, issuer:UserSession) 
    {
        var issuerColor:Null<PieceColor> = sessions.getPlayerColor(issuer);

        if (issuerColor == null && !action.match(Message(_) | RequestTimeoutCheck))
            return;

        switch action 
        {
            case Move(fromI, toI, fromJ, toJ, morphInto):
                performMove(issuer, fromI, toI, fromJ, toJ, morphInto);
            case RequestTimeoutCheck:
                time.checkTime(state.turnColor(), state.moveNum);
            case Message(text):
                sendMessage(issuer, text);
            case Resign:
                endGame(Decisive(Resign, opposite(issuerColor)));
            case OfferDraw:
                log.append(Event(DrawOffered(issuerColor)));
                offers.offerDraw(issuerColor);
                sessions.broadcast(DrawOffered);
            case CancelDraw:
                log.append(Event(DrawCanceled(issuerColor)));
                offers.cancelDraw(issuerColor);
                sessions.broadcast(DrawCancelled);
            case AcceptDraw:
                log.append(Event(DrawAccepted(issuerColor)));
                offers.acceptDraw(issuerColor);
                sessions.broadcast(DrawAccepted);
            case DeclineDraw:
                log.append(Event(DrawDeclined(issuerColor)));
                offers.declineDraw(issuerColor);
                sessions.broadcast(DrawDeclined);
            case OfferTakeback:
                log.append(Event(TakebackOffered(issuerColor)));
                offers.offerTakeback(issuerColor);
                sessions.broadcast(TakebackOffered);
            case CancelTakeback:
                log.append(Event(TakebackCanceled(issuerColor)));
                offers.cancelTakeback(issuerColor);
                sessions.broadcast(TakebackCancelled);
            case AcceptTakeback:
                log.append(Event(TakebackAccepted(issuerColor)));
                offers.acceptTakeback(issuerColor);
                sessions.broadcast(TakebackAccepted);
            case DeclineTakeback:
                log.append(Event(TakebackDeclined(issuerColor)));
                offers.declineTakeback(issuerColor);
                sessions.broadcast(TakebackDeclined);
            case AddTime:
                time.addTime(opposite(issuerColor), state.turnColor(), state.moveNum);
                sessions.broadcast(TimeCorrection(getTime()));
        }
    }

    //TODO: handle disconnect/connect (also for spectators and guests)

    private function new(id:Int, onEndedCallback:Outcome->Game->Void) 
    {
        this.id = id;
        this.onEndedCallback = onEndedCallback;
    }
}