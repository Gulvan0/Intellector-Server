package struct;

import net.shared.PieceType;

enum Ply 
{
    NormalMove(from:Int, to:Int, movingPiece:PieceType);
    NormalCapture(from:Int, to:Int, capturingPiece:PieceType, capturedPiece:PieceType);
    ChameleonCapture(from:Int, to:Int, capturingPiece:PieceType, capturedPiece:PieceType);
    Promotion(from:Int, to:Int, promotedTo:PieceType);
    PromotionWithCapture(from:Int, to:Int, capturedPiece:PieceType, promotedTo:PieceType);
    Castling(from:Int, to:Int);
}