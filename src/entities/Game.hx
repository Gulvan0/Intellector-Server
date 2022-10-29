package entities;

import struct.ChallengeParams;
import struct.TimeControl;
import net.shared.GameInfo;
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
        var authorColor:Null<PieceColor> = sessions.getPresentPlayerColor(author);
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

        GameManager.onGameEnded(outcome, this);
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
        var issuerColor:Null<PieceColor> = sessions.getPresentPlayerColor(issuer);

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
                if (state.moveNum >= 2)
                    endGame(Decisive(Resign, opposite(issuerColor)));
                else
                    endGame(Drawish(Abort));
            case OfferDraw:
                if (state.moveNum < 2)
                    return;
                log.append(Event(DrawOffered(issuerColor)));
                offers.offerDraw(issuerColor);
                sessions.broadcast(DrawOffered, issuer);
            case CancelDraw:
                log.append(Event(DrawCanceled(issuerColor)));
                offers.cancelDraw(issuerColor);
                sessions.broadcast(DrawCancelled, issuer);
            case AcceptDraw:
                log.append(Event(DrawAccepted(issuerColor)));
                offers.acceptDraw(issuerColor);
                sessions.broadcast(DrawAccepted, issuer);
            case DeclineDraw:
                log.append(Event(DrawDeclined(issuerColor)));
                offers.declineDraw(issuerColor);
                sessions.broadcast(DrawDeclined, issuer);
            case OfferTakeback:
                if (state.moveNum == 0 || (state.moveNum == 1 && state.turnColor() == issuerColor))
                    return;
                log.append(Event(TakebackOffered(issuerColor)));
                offers.offerTakeback(issuerColor);
                sessions.broadcast(TakebackOffered, issuer);
            case CancelTakeback:
                log.append(Event(TakebackCanceled(issuerColor)));
                offers.cancelTakeback(issuerColor);
                sessions.broadcast(TakebackCancelled, issuer);
            case AcceptTakeback:
                log.append(Event(TakebackAccepted(issuerColor)));
                offers.acceptTakeback(issuerColor);
                sessions.broadcast(TakebackAccepted, issuer);
            case DeclineTakeback:
                log.append(Event(TakebackDeclined(issuerColor)));
                offers.declineTakeback(issuerColor);
                sessions.broadcast(TakebackDeclined, issuer);
            case AddTime:
                if (state.moveNum == 0)
                    return;
                var receiverColor:PieceColor = opposite(issuerColor);
                log.addTime(receiverColor);
                time.addTime(receiverColor, state.turnColor(), state.moveNum);
                sessions.broadcast(TimeAdded(receiverColor, getTime()));
        }
    }

    public function onUserLeft(user:UserSession) 
    {
        var playerColor:Null<PieceColor> = sessions.getPresentPlayerColor(user);

        if (playerColor != null)
        {
            sessions.removePlayer(playerColor);
            log.append(Event(PlayerDisconnected(playerColor)));
            sessions.broadcast(PlayerDisconnected(playerColor));
        }
        else
        {
            sessions.removeSpectator(user);
            sessions.broadcast(SpectatorLeft(user.login));
        }
    }

    public function onPlayerJoined(playerColor:PieceColor, session:UserSession) 
    {
        sessions.attachPlayer(playerColor, session);
        log.append(Event(PlayerReconnected(playerColor)));
        sessions.broadcast(PlayerReconnected(playerColor));
    }

    public function onSpectatorJoined(spectator:UserSession) 
    {
        sessions.addSpectator(spectator);
        sessions.broadcast(NewSpectator(spectator.login));
    }

    public function onPresentUserDisconnected(user:UserSession) 
    {
        var playerColor:Null<PieceColor> = sessions.getPresentPlayerColor(user);
        if (playerColor != null)
        {
            log.append(Event(PlayerDisconnected(playerColor)));
            sessions.broadcast(PlayerDisconnected(playerColor));
        }
        else
            sessions.broadcast(SpectatorLeft(user.login));
    }

    public function onPresentUserReconnected(user:UserSession) 
    {
        var playerColor:Null<PieceColor> = sessions.getPresentPlayerColor(user);
        if (playerColor != null)
        {
            log.append(Event(PlayerReconnected(playerColor)));
            sessions.broadcast(PlayerReconnected(playerColor));
        }
        else
            sessions.broadcast(NewSpectator(user.login));
    }

    public function onSessionDestroyed(user:UserSession) 
    {
        var playerColor:Null<PieceColor> = sessions.getPresentPlayerColor(user); 
        sessions.removeSession(user);
        if (playerColor != null && user.isGuest())
            endGame(Decisive(Abandon, opposite(playerColor)));
    }

    public function getInfo():GameInfo
    {
        var info:GameInfo = new GameInfo();
        info.id = id;
        info.log = log.get();
        return info;
    }

    public function getSimpleRematchParams():Map<String, ChallengeParams>
    {   
        var map:Map<String, ChallengeParams> = [];

        for (color in PieceColor.createAll())
        {
            var playerLogin:Null<String> = log.playerLogins.get(color);
            var opponent:Null<UserSession> = sessions.getPresentPlayerSession(opposite(color));

            if (playerLogin == null || opponent == null)
                continue;

            var opponentRef:String = opponent.getInteractionReference();
            var params:ChallengeParams = new ChallengeParams(log.timeControl, Direct(opponentRef), color, log.customStartingSituation, log.rated);

            map.set(playerLogin, params);
        }

        return map;
    }

    public static function create(id:Int, players:Map<PieceColor, Null<UserSession>>, timeControl:TimeControl, rated:Bool, ?customStartingSituation:Situation):Game
    {
        if (timeControl.isCorrespondence())
            return CorrespondenceGame.createNew(id, players, rated, customStartingSituation);
        else
            return new FiniteTimeGame(id, players, timeControl, rated, customStartingSituation);
    }

    private function new(id:Int) 
    {
        this.id = id;
    }
}