package entities.util;

import net.shared.PieceColor;

class GameOffers 
{
    private var hasPendingDrawRequest:Map<PieceColor, Bool> = [White => false, Black => false];
    private var hasPendingTakebackRequest:Map<PieceColor, Bool> = [White => false, Black => false];

    private var onDrawAchieved:Void->Void;
    private var onRollbackNeeded:PieceColor->Void;
    
    public function offerDraw(requestedBy:PieceColor):Bool
    {
        if (hasPendingDrawRequest[requestedBy])
            return false;

        hasPendingDrawRequest[requestedBy] = true;
        return true;
    }

    public function cancelDraw(requestedBy:PieceColor):Bool 
    {
        if (!hasPendingDrawRequest[requestedBy])
            return false;

        hasPendingDrawRequest[requestedBy] = false;
        return true;
    }

    public function acceptDraw(requestedBy:PieceColor):Bool
    {
        if (!hasPendingDrawRequest[opposite(requestedBy)])
            return false;

        hasPendingDrawRequest = [White => false, Black => false];
        hasPendingTakebackRequest = [White => false, Black => false];

        onDrawAchieved();
        return true;
    }

    public function declineDraw(requestedBy:PieceColor):Bool
    {
        if (!hasPendingDrawRequest[opposite(requestedBy)])
            return false;

        hasPendingDrawRequest[opposite(requestedBy)] = false;
        return true;
    }
    
    public function offerTakeback(requestedBy:PieceColor):Bool 
    {
        if (hasPendingTakebackRequest[requestedBy])
            return false;

        hasPendingTakebackRequest[requestedBy] = true;
        return true;
    }

    public function cancelTakeback(requestedBy:PieceColor):Bool 
    {
        if (!hasPendingTakebackRequest[requestedBy])
            return false;

        hasPendingTakebackRequest[requestedBy] = false;
        return true;
    }

    public function acceptTakeback(requestedBy:PieceColor):Bool 
    {
        if (!hasPendingTakebackRequest[opposite(requestedBy)])
            return false;

        hasPendingDrawRequest = [White => false, Black => false];
        hasPendingTakebackRequest = [White => false, Black => false];

        onRollbackNeeded(opposite(requestedBy));
        return true;
    }

    public function declineTakeback(requestedBy:PieceColor):Bool 
    {
        if (!hasPendingTakebackRequest[opposite(requestedBy)])
            return false;

        hasPendingTakebackRequest[opposite(requestedBy)] = false;
        return true;
    }

    public function onMoveMade() 
    {
        hasPendingDrawRequest = [White => false, Black => false];
        hasPendingTakebackRequest = [White => false, Black => false];
    }

    public static function createFromLog(parsedLog:Array<GameLogEntry>, onDrawAchieved:Void->Void, onRollbackNeeded:PieceColor->Void):GameOffers
    {
        var offers:GameOffers = new GameOffers(onDrawAchieved, onRollbackNeeded);

        for (entry in parsedLog)
            switch entry 
            {
                case Move(_, _, _):
                    offers.onMoveMade();
                case Event(DrawOffered(offerOwnerColor)):
                    offers.offerDraw(offerOwnerColor);
                case Event(DrawCanceled(offerOwnerColor)):
                    offers.cancelDraw(offerOwnerColor);
                case Event(DrawAccepted(offerReceiverColor)):
                    offers.acceptDraw(offerReceiverColor);
                case Event(DrawDeclined(offerReceiverColor)):
                    offers.declineDraw(offerReceiverColor);
                case Event(TakebackOffered(offerOwnerColor)):
                    offers.offerTakeback(offerOwnerColor);
                case Event(TakebackCanceled(offerOwnerColor)):
                    offers.cancelTakeback(offerOwnerColor);
                case Event(TakebackAccepted(offerReceiverColor)):
                    offers.acceptTakeback(offerReceiverColor);
                case Event(TakebackDeclined(offerReceiverColor)):
                    offers.declineTakeback(offerReceiverColor);
                default:
            }

        return offers;
    }

    public function new(onDrawAchieved:Void->Void, onRollbackNeeded:PieceColor->Void) 
    {
        this.onDrawAchieved = onDrawAchieved;
        this.onRollbackNeeded = onRollbackNeeded;
    }
}