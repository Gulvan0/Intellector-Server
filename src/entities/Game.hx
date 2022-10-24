package entities;

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
    private var id:Int;

    public var log:GameLog;
    public var offers:GameOffers;
    public var sessions:GameSessions;
    public var state:GameState;
    public var time:IGameTime;

    //TODO: Write to log
    
    //TODO: Emit events

    private function performMove(author:UserSession, fromI:Int, toI:Int, fromJ:Int, toJ:Int, morphInto:Null<PieceType>) 
    {
        //TODO: Fill
        //If success: offers.onMoveMade(); time.onMoveMade(); Notify spectators and opponent
    }

    private function sendMessage(author:UserSession, text:String) 
    {
        //TODO: Fill
    }

    private function endGame(outcome:Outcome) 
    {
        time.stopTime();
        //TODO: Fill
    }

    private function rollback(requestedBy:PieceColor) 
    {
        //TODO: Fill
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
                time.checkTime();
            case Message(text):
                sendMessage(issuer, text);
            case Resign:
                endGame(Decisive(Resign, opposite(issuerColor)));
            case OfferDraw:
                offers.offerDraw(issuerColor);
            case CancelDraw:
                offers.cancelDraw(issuerColor);
            case AcceptDraw:
                offers.acceptDraw(issuerColor);
            case DeclineDraw:
                offers.declineDraw(issuerColor);
            case OfferTakeback:
                offers.offerTakeback(issuerColor);
            case CancelTakeback:
                offers.cancelTakeback(issuerColor);
            case AcceptTakeback:
                offers.acceptTakeback(issuerColor);
            case DeclineTakeback:
                offers.declineTakeback(issuerColor);
            case AddTime:
                time.addTime(opposite(issuerColor));
        }
    }

    //TODO: Correspondence spectator notification, handle disconnect/connect - how to implement???

    public function new(id:Int) 
    {
        this.id = id;
    }
}