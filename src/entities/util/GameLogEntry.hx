package entities.util;

import net.shared.Outcome;
import net.shared.PieceColor;
import struct.TimeControl;
import struct.Situation;
import net.shared.EloValue;
import net.shared.PieceType;
import struct.HexCoords;

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
    Move(from:HexCoords, to:HexCoords, morphInto:Null<PieceType>, msLeftWhite:Null<Int>, msLeftBlack:Null<Int>);
    Players(whiteLogin:Null<String>, blackLogin:Null<String>);
    Elo(whiteElo:EloValue, blackElo:EloValue);
    DateTime(ts:Date);
    MsLeft(whiteMs:Int, blackMs:Int);
    CustomStartingSituation(situation:Situation);
    TimeControl(timeControl:TimeControl);
    PlayerMessage(authorColor:PieceColor, messageText:String);
    Result(outcome:Outcome);
    Event(event:Event);
}