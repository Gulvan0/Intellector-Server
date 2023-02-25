package entities.util;

import net.shared.TimeControl;
import net.shared.board.RawPly;
import net.shared.Outcome;
import net.shared.PieceColor;
import net.shared.board.Situation;
import net.shared.EloValue;
import net.shared.PieceType;
import net.shared.board.HexCoords;

enum Event
{
    PlayerDisconnected(color:PieceColor);
    PlayerReconnected(color:PieceColor);
    DrawOffered(offerOwnerColor:PieceColor);
    DrawCanceled(offerOwnerColor:PieceColor);
    DrawAccepted(offerReceiverColor:PieceColor);
    DrawDeclined(offerReceiverColor:PieceColor);
    TakebackOffered(offerOwnerColor:PieceColor);
    TakebackCanceled(offerOwnerColor:PieceColor);
    TakebackAccepted(offerReceiverColor:PieceColor);
    TakebackDeclined(offerReceiverColor:PieceColor);
    TimeAdded(bonusTimeReceiverColor:PieceColor);
}

enum GameLogEntry 
{
    Move(rawPly:RawPly, msLeftWhite:Null<Int>, msLeftBlack:Null<Int>);
    Players(whiteRef:String, blackRef:String);
    Elo(whiteElo:EloValue, blackElo:EloValue);
    DateTime(ts:Date);
    MsLeft(whiteMs:Int, blackMs:Int);
    CustomStartingSituation(situation:Situation);
    TimeControl(timeControl:TimeControl);
    PlayerMessage(authorColor:PieceColor, messageText:String);
    Result(outcome:Outcome);
    Event(event:Event);
}