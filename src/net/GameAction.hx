package net;

import net.shared.board.RawPly;
import net.shared.PieceType;

enum GameAction 
{
    Move(rawPly:RawPly); 
    Message(text:String);
    Resign; 
    OfferDraw; 
    CancelDraw; 
    AcceptDraw; 
    DeclineDraw; 
    OfferTakeback; 
    CancelTakeback; 
    AcceptTakeback; 
    DeclineTakeback;
    AddTime;
}