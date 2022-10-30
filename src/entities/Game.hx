package entities;

import services.Auth;
import net.shared.Constants;
import services.Logger;
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
    private final serviceName:String;

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
                Logger.serviceLog(serviceName, '${author.getInteractionReference()} ($turnColor) successfully performed a move');
                onMoveSuccessful(author, turnColor, state.moveNum - 1, from, to, morphInto);
            case GameEnded(outcome):
                Logger.serviceLog(serviceName, '${author.getInteractionReference()} ($turnColor) successfully performed a game-finishing move');
                onMoveSuccessful(author, turnColor, state.moveNum - 1, from, to, morphInto);
                endGame(outcome);
            case Failed:
                Logger.serviceLog(serviceName, '${author.getInteractionReference()} ($turnColor) attempted to perform invalid move: ($fromI, $fromJ) -> ($toI, $toJ) / Morph $morphInto; board SIP: ${state.getSIP()}');
                sessions.tellPlayer(turnColor, InvalidMove);
        }
    }

    private function sendMessage(author:UserSession, text:String) 
    {
        var authorColor:Null<PieceColor> = sessions.getPresentPlayerColor(author);
        if (authorColor != null)
        {
            log.append(PlayerMessage(authorColor, text));
            sessions.broadcast(Message(author.getLogReference(), text), author);
        }
        else
            sessions.broadcast(SpectatorMessage(author.getLogReference(), text), author);
    }

    private function endGame(outcome:Outcome) 
    {
        Logger.serviceLog(serviceName, 'Ending game with outcome $outcome');

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

        Logger.serviceLog(serviceName, 'Applying rollback for $moveCnt moves');

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
                Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) demanded timeout check; performing');
                time.checkTime(state.turnColor(), state.moveNum);
            case Message(text):
                sendMessage(issuer, text);
            case Resign:
                if (state.moveNum >= 2)
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) resigned on move ${state.moveNum} => resigning');
                    endGame(Decisive(Resign, opposite(issuerColor)));
                }
                else
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) resigned on move ${state.moveNum} => aborting');
                    endGame(Drawish(Abort));
                }
            case OfferDraw:
                if (state.moveNum < 2)
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) offered draw too early: at move ${state.moveNum}');
                    return;
                }

                if (offers.offerDraw(issuerColor))
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) offered draw. Success');
                    log.append(Event(DrawOffered(issuerColor)));
                    sessions.broadcast(DrawOffered(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) tried to offer a draw, but failed');
            case CancelDraw:
                if (offers.cancelDraw(issuerColor))
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) cancelled draw. Success');
                    log.append(Event(DrawCanceled(issuerColor)));
                    sessions.broadcast(DrawCancelled(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) tried to cancel a draw, but failed');
            case AcceptDraw:
                if (offers.acceptDraw(issuerColor))
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) accepted draw. Success');
                    log.append(Event(DrawAccepted(issuerColor)));
                    sessions.broadcast(DrawAccepted(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) tried to accept a draw, but failed');
            case DeclineDraw:
                if (offers.declineDraw(issuerColor))
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) declined draw. Success');
                    log.append(Event(DrawDeclined(issuerColor)));
                    sessions.broadcast(DrawDeclined(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) tried to decline a draw, but failed');
            case OfferTakeback:
                if (state.moveNum == 0 || (state.moveNum == 1 && state.turnColor() == issuerColor))
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) offered a takeback too early: on move ${state.moveNum}');
                    return;
                }

                if (offers.offerTakeback(issuerColor))
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) offered a takeback. Success');
                    log.append(Event(TakebackOffered(issuerColor)));
                    sessions.broadcast(TakebackOffered(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) tried to offer a takeback, but failed');
            case CancelTakeback:
                if (offers.cancelTakeback(issuerColor))
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) cancelled a takeback. Success');
                    log.append(Event(TakebackCanceled(issuerColor)));
                    sessions.broadcast(TakebackCancelled(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) tried to cancel a takeback, but failed');
            case AcceptTakeback:
                if (offers.acceptTakeback(issuerColor))
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) accepted a takeback. Success');
                    log.append(Event(TakebackAccepted(issuerColor)));
                    sessions.broadcast(TakebackAccepted(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) tried to accept a takeback, but failed');
            case DeclineTakeback:
                if (offers.declineTakeback(issuerColor))
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) declined a takeback. Success');
                    log.append(Event(TakebackDeclined(issuerColor)));
                    sessions.broadcast(TakebackDeclined(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) tried to decline a takeback, but failed');
            case AddTime:
                if (state.moveNum == 0)
                {
                    Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) tried to add time too early: on move ${state.moveNum}');
                    return;
                }
                
                Logger.serviceLog(serviceName, '${issuer.getInteractionReference()} ($issuerColor) added some time to their opponent (+ ${Constants.msAddedByOpponent} ms)');
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
            Logger.serviceLog(serviceName, 'Player ${user.getLogReference()} ($playerColor) left');
            sessions.removePlayer(playerColor);
            log.append(Event(PlayerDisconnected(playerColor)));
            sessions.broadcast(PlayerDisconnected(playerColor));
        }
        else
        {
            Logger.serviceLog(serviceName, 'Spectator ${user.getLogReference()} left');
            sessions.removeSpectator(user);
            sessions.broadcast(SpectatorLeft(user.getLogReference()));
        }
    }

    public function onPlayerJoined(playerColor:PieceColor, session:UserSession) 
    {
        Logger.serviceLog(serviceName, 'Player ${session.getLogReference()} ($playerColor) joined');
        sessions.attachPlayer(playerColor, session);
        log.append(Event(PlayerReconnected(playerColor)));
        sessions.broadcast(PlayerReconnected(playerColor));
    }

    public function onSpectatorJoined(spectator:UserSession) 
    {
        Logger.serviceLog(serviceName, 'Spectator ${spectator.getLogReference()} joined');
        sessions.addSpectator(spectator);
        sessions.broadcast(NewSpectator(spectator.getLogReference()));
    }

    public function onPresentUserDisconnected(user:UserSession) 
    {
        var playerColor:Null<PieceColor> = sessions.getPresentPlayerColor(user);
        if (playerColor != null)
        {
            Logger.serviceLog(serviceName, 'Player ${user.getLogReference()} ($playerColor) disconnected');
            log.append(Event(PlayerDisconnected(playerColor)));
            sessions.broadcast(PlayerDisconnected(playerColor));
        }
        else
        {
            Logger.serviceLog(serviceName, 'Spectator ${user.getLogReference()} disconnected');
            sessions.broadcast(SpectatorLeft(user.getLogReference()));
        }
    }

    public function onPresentUserReconnected(user:UserSession) 
    {
        var playerColor:Null<PieceColor> = sessions.getPresentPlayerColor(user);
        if (playerColor != null)
        {
            Logger.serviceLog(serviceName, 'Player ${user.getLogReference()} ($playerColor) reconnected');
            log.append(Event(PlayerReconnected(playerColor)));
            sessions.broadcast(PlayerReconnected(playerColor));
        }
        else
        {
            Logger.serviceLog(serviceName, 'Spectator ${user.getLogReference()} reconnected');
            sessions.broadcast(NewSpectator(user.getLogReference()));
        }
    }

    public function onSessionDestroyed(user:UserSession) 
    {
        Logger.serviceLog(serviceName, 'Removing session ${user.getLogReference()} as it was destroyed');
        var playerColor:Null<PieceColor> = sessions.getPresentPlayerColor(user); 
        sessions.removeSession(user);
        if (playerColor != null && user.isGuest())
        {
            Logger.serviceLog(serviceName, 'The destroyed session ${user.getLogReference()} belongs to a guest, ending the game as well');
            endGame(Decisive(Abandon, opposite(playerColor)));
        }
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
            var playerLogin:String = log.playerRefs.get(color);
            var opponent:Null<UserSession> = sessions.getPresentPlayerSession(opposite(color));

            if (Auth.isGuest(playerLogin) || opponent == null)
                continue;

            var opponentRef:String = opponent.getInteractionReference();
            var params:ChallengeParams = new ChallengeParams(log.timeControl, Direct(opponentRef), color, log.customStartingSituation, log.rated);

            map.set(playerLogin, params);
        }

        return map;
    }

    public static function create(id:Int, players:Map<PieceColor, UserSession>, timeControl:TimeControl, rated:Bool, ?customStartingSituation:Situation):Game
    {
        if (timeControl.isCorrespondence())
            return CorrespondenceGame.createNew(id, players, rated, customStartingSituation);
        else
            return new FiniteTimeGame(id, players, timeControl, rated, customStartingSituation);
    }

    private function new(id:Int) 
    {
        this.serviceName = 'GAME_($id)';
        this.id = id;
    }
}