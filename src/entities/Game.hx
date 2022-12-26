package entities;

import net.shared.board.RawPly;
import services.Auth;
import net.shared.Constants;
import services.Logger;
import struct.ChallengeParams;
import struct.TimeControl;
import net.shared.dataobj.GameInfo;
import net.shared.dataobj.TimeReservesData;
import services.EloManager;
import entities.util.GameTime.IGameTime;
import net.shared.Outcome;
import net.GameAction;
import net.shared.dataobj.TimeReservesData;
import entities.util.GameLog;
import entities.util.GameState;
import entities.util.GameSessions;
import entities.util.GameOffers;
import services.GameManager;
import utils.ds.DefaultCountMap;
import net.shared.board.HexCoords;
import net.shared.ServerEvent;
import net.shared.PieceType;
import net.shared.board.MaterializedPly;
import net.shared.board.Situation;
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

    private var temporarilyOfflineUserRefs:Array<String> = [];

    public function getTime():Null<TimeReservesData> 
    {
        return time.getTime(state.turnColor(), state.moveNum);
    }

    private function onMoveSuccessful(author:UserSession, turnColor:PieceColor, moveNum:Int, rawPly:RawPly) 
    {
        time.onMoveMade(turnColor, moveNum);

        var msAtMoveStart = time.getMsAtMoveStart();
        var whiteMs = msAtMoveStart != null? msAtMoveStart.get(White) : null;
        var blackMs = msAtMoveStart != null? msAtMoveStart.get(Black) : null;

        var actualTimeData = getTime();

        log.append(Move(rawPly, whiteMs, blackMs));
        offers.onMoveMade();
        sessions.broadcast(Move(rawPly, actualTimeData), author);
        if (actualTimeData != null)
            sessions.tellPlayer(turnColor, TimeCorrection(actualTimeData));
    }

    private function performMove(author:UserSession, rawPly:RawPly) 
    {
        var turnColor:PieceColor = state.turnColor();
        var authorColor:PieceColor = log.getColorByRef(author);
        var result:TryPlyResult = state.tryPly(rawPly);

        switch result 
        {
            case Performed:
                Logger.serviceLog(serviceName, '$author ($authorColor) successfully performed a move');
                onMoveSuccessful(author, turnColor, state.moveNum - 1, rawPly);
            case GameEnded(outcome):
                Logger.serviceLog(serviceName, '$author ($authorColor) successfully performed a game-finishing move');
                onMoveSuccessful(author, turnColor, state.moveNum - 1, rawPly);
                endGame(outcome);
            case Failed:
                Logger.serviceLog(serviceName, '$author ($authorColor) attempted to perform invalid move: $rawPly; board SIP: ${state.getSIP()}');
                sessions.tellPlayer(authorColor, InvalidMove);
        }
    }

    private function sendMessage(author:UserSession, text:String) 
    {
        var authorColor:Null<PieceColor> = log.getColorByRef(author);
        if (authorColor != null)
        {
            log.append(PlayerMessage(authorColor, text));
            sessions.broadcast(Message(author.getReference(), text), author);
        }
        else
            sessions.broadcast(SpectatorMessage(author.getReference(), text), author);
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
        var issuerColor:Null<PieceColor> = log.getColorByRef(issuer);

        if (issuerColor == null && !action.match(Message(_)))
            return;

        switch action 
        {
            case Move(rawPly):
                performMove(issuer, rawPly);
            case Message(text):
                sendMessage(issuer, text);
            case Resign:
                if (state.moveNum >= 2)
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) resigned on move ${state.moveNum} => resigning');
                    endGame(Decisive(Resign, opposite(issuerColor)));
                }
                else
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) resigned on move ${state.moveNum} => aborting');
                    endGame(Drawish(Abort));
                }
            case OfferDraw:
                if (state.moveNum < 2)
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) offered draw too early: at move ${state.moveNum}');
                    return;
                }

                if (offers.offerDraw(issuerColor))
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) offered draw. Success');
                    log.append(Event(DrawOffered(issuerColor)));
                    sessions.broadcast(DrawOffered(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) tried to offer a draw, but failed');
            case CancelDraw:
                if (offers.cancelDraw(issuerColor))
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) cancelled draw. Success');
                    log.append(Event(DrawCanceled(issuerColor)));
                    sessions.broadcast(DrawCancelled(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) tried to cancel a draw, but failed');
            case AcceptDraw:
                if (offers.acceptDraw(issuerColor))
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) accepted draw. Success');
                    log.append(Event(DrawAccepted(issuerColor)));
                    sessions.broadcast(DrawAccepted(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) tried to accept a draw, but failed');
            case DeclineDraw:
                if (offers.declineDraw(issuerColor))
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) declined draw. Success');
                    log.append(Event(DrawDeclined(issuerColor)));
                    sessions.broadcast(DrawDeclined(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) tried to decline a draw, but failed');
            case OfferTakeback:
                if (state.moveNum == 0 || (state.moveNum == 1 && state.turnColor() == issuerColor))
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) offered a takeback too early: on move ${state.moveNum}');
                    return;
                }

                if (offers.offerTakeback(issuerColor))
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) offered a takeback. Success');
                    log.append(Event(TakebackOffered(issuerColor)));
                    sessions.broadcast(TakebackOffered(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) tried to offer a takeback, but failed');
            case CancelTakeback:
                if (offers.cancelTakeback(issuerColor))
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) cancelled a takeback. Success');
                    log.append(Event(TakebackCanceled(issuerColor)));
                    sessions.broadcast(TakebackCancelled(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) tried to cancel a takeback, but failed');
            case AcceptTakeback:
                if (offers.acceptTakeback(issuerColor))
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) accepted a takeback. Success');
                    log.append(Event(TakebackAccepted(issuerColor)));
                    sessions.broadcast(TakebackAccepted(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) tried to accept a takeback, but failed');
            case DeclineTakeback:
                if (offers.declineTakeback(issuerColor))
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) declined a takeback. Success');
                    log.append(Event(TakebackDeclined(issuerColor)));
                    sessions.broadcast(TakebackDeclined(issuerColor), issuer);
                }
                else
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) tried to decline a takeback, but failed');
            case AddTime:
                if (state.moveNum == 0)
                {
                    Logger.serviceLog(serviceName, '$issuer ($issuerColor) tried to add time too early: on move ${state.moveNum}');
                    return;
                }
                
                Logger.serviceLog(serviceName, '$issuer ($issuerColor) added some time to their opponent (+ ${Constants.msAddedByOpponent} ms)');
                var receiverColor:PieceColor = opposite(issuerColor);
                log.append(Event(TimeAdded(receiverColor)));
                time.addTime(receiverColor, state.turnColor(), state.moveNum);
                sessions.broadcast(TimeAdded(receiverColor, getTime()));
        }
    }

    public function resendPendingOffers(receiver:UserSession) 
    {
        var receiverColor:Null<PieceColor> = log.getColorByRef(receiver);
        if (receiverColor == null)
            return;
        
        if (offers.hasIncomingDrawRequest(receiverColor))
            sessions.tellPlayer(receiverColor, DrawOffered(opposite(receiverColor)));
        if (offers.hasIncomingTakebackRequest(receiverColor))
            sessions.tellPlayer(receiverColor, TakebackOffered(opposite(receiverColor)));
    }

    public function onUserLeftToOtherPage(user:UserSession) 
    {
        var playerColor:Null<PieceColor> = log.getColorByRef(user);

        if (playerColor != null)
        {
            Logger.serviceLog(serviceName, 'Player $user ($playerColor) left');
            sessions.removePlayer(playerColor);
            log.append(Event(PlayerDisconnected(playerColor)));
            sessions.broadcast(PlayerDisconnected(playerColor));
        }
        else
        {
            Logger.serviceLog(serviceName, 'Spectator $user left');
            sessions.removeSpectator(user);
            sessions.broadcast(SpectatorLeft(user.getReference()));
        }

        checkDerelictness();
    }

    public function onPlayerJoined(session:UserSession) 
    {
        var playerColor:Null<PieceColor> = log.getColorByRef(session);

        if (playerColor == null)
        {
            Logger.logError('$session is not a player in game $id, but onPlayerJoined() was called');
            onSpectatorJoined(session);
            return;
        }

        Logger.serviceLog(serviceName, 'Player $session ($playerColor) joined');
        sessions.attachPlayer(playerColor, session);
        log.append(Event(PlayerReconnected(playerColor)));
        sessions.broadcast(PlayerReconnected(playerColor));
    }

    public function onSpectatorJoined(spectator:UserSession) 
    {
        Logger.serviceLog(serviceName, 'Spectator $spectator joined');
        sessions.addSpectator(spectator);
        sessions.broadcast(NewSpectator(spectator.getReference()));
    }

    public function onPresentUserDisconnected(user:UserSession) 
    {
        if (temporarilyOfflineUserRefs.contains(user.getReference()))
            return;

        var playerColor:Null<PieceColor> = log.getColorByRef(user);
        
        if (playerColor != null)
        {
            if (!sessions.playerIngame(playerColor))
                return;
            
            Logger.serviceLog(serviceName, 'Player $user ($playerColor) disconnected');
            log.append(Event(PlayerDisconnected(playerColor)));
            sessions.broadcast(PlayerDisconnected(playerColor));
        }
        else
        {
            if (!sessions.spectatorIngame(user))
                return;

            Logger.serviceLog(serviceName, 'Spectator $user disconnected');
            sessions.broadcast(SpectatorLeft(user.getReference()));
        }

        temporarilyOfflineUserRefs.push(user.getReference());
    }

    public function onPresentUserReconnected(user:UserSession) 
    {
        if (!temporarilyOfflineUserRefs.contains(user.getReference()))
            return;

        var playerColor:Null<PieceColor> = log.getColorByRef(user);
        if (playerColor != null)
        {
            Logger.serviceLog(serviceName, 'Player $user ($playerColor) reconnected');
            log.append(Event(PlayerReconnected(playerColor)));
            sessions.broadcast(PlayerReconnected(playerColor));
        }
        else
        {
            Logger.serviceLog(serviceName, 'Spectator $user reconnected');
            sessions.broadcast(NewSpectator(user.getReference()));
        }

        temporarilyOfflineUserRefs.remove(user.getReference());
    }

    public function onSessionDestroyed(user:UserSession) 
    {
        Logger.serviceLog(serviceName, 'Attempting to remove session $user as it was destroyed');

        var playerColor:Null<PieceColor> = log.getColorByRef(user);

        if (playerColor != null && !sessions.playerIngame(playerColor))
            return;
        else if (playerColor == null && !sessions.spectatorIngame(user))
            return;

        Logger.serviceLog(serviceName, 'Removing session $user as it was destroyed');
        temporarilyOfflineUserRefs.remove(user.getReference());
        sessions.removeSession(user);

        if (playerColor != null && user.isGuest())
        {
            Logger.serviceLog(serviceName, 'The destroyed session $user belongs to a guest, ending the game as well');
            endGame(Decisive(Abandon, opposite(playerColor)));
        }
        else
            checkDerelictness();
    }

    private function checkDerelictness()
    {
        if (sessions.isDerelict(true) && state.moveNum < 2)
            abortGame();
        else if (sessions.isDerelict() && log.timeControl.isCorrespondence())
            GameManager.unloadDerelictCorrespondence(id);
    }

    public function abortGame() 
    {
        endGame(Drawish(Abort));
        Logger.serviceLog(serviceName, 'Aborted game $id by request');
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
            var playerRef:String = log.playerRefs.get(color);
            var opponentRef:String = log.playerRefs.get(opposite(color));

            if (Auth.isGuest(playerRef))
                continue;

            var params:ChallengeParams = new ChallengeParams(log.timeControl, Direct(opponentRef), color, log.customStartingSituation, log.rated);
            map.set(playerRef, params);
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