package struct;

import net.shared.PieceColor;
import struct.HexCoords;
import net.shared.PieceType;

enum Ply 
{
    NormalMove(from:HexCoords, to:HexCoords, movingPiece:PieceType);
    NormalCapture(from:HexCoords, to:HexCoords, capturingPiece:PieceType, capturedPiece:PieceType);
    ChameleonCapture(from:HexCoords, to:HexCoords, capturingPiece:PieceType, capturedPiece:PieceType);
    Promotion(from:HexCoords, to:HexCoords, promotedTo:PieceType);
    PromotionWithCapture(from:HexCoords, to:HexCoords, capturedPiece:PieceType, promotedTo:PieceType);
    Castling(from:HexCoords, to:HexCoords);
}

function construct(pieces:PieceArrangement, from:HexCoords, to:HexCoords, morphInto:Null<PieceType>):Ply 
{
    if (!pieces.empty(to))
        if (pieces.colorAt(from) == pieces.colorAt(to))
            return Castling(from, to);
        else if (morphInto == null)
            return NormalCapture(from, to, pieces.typeAt(from), pieces.typeAt(to));
        else if (pieces.typeAt(from) == Progressor)
            return PromotionWithCapture(from, to, pieces.typeAt(to), morphInto);
        else
            return ChameleonCapture(from, to, pieces.typeAt(from), pieces.typeAt(from));
    else if (morphInto != null)
        return Promotion(from, to, morphInto);
    else
        return NormalMove(from, to, pieces.typeAt(from));
}

function isMating(ply:Ply):Bool
{
    switch ply 
    {
        case NormalCapture(_, _, _, capturedPiece), ChameleonCapture(_, _, _, capturedPiece), PromotionWithCapture(_, _, capturedPiece, _):
            return capturedPiece == Intellector;
        default:
            return false;
    }
}

function isBreakthrough(ply:Ply, pieces:PieceArrangement, turnColor:PieceColor):Bool
{
    switch ply 
    {
        case NormalMove(from, to, movingPiece):
            return movingPiece == Intellector && to.isFinal(turnColor);
        case Castling(from, to):
            if (pieces.typeAt(from) == Intellector)
                return to.isFinal(turnColor);
            else
                return from.isFinal(turnColor);
        default:
            return false;
    }
}

function isProgressive(ply:Ply):Bool
{
    switch ply 
    {
        case NormalMove(_, _, movingPiece):
            return movingPiece == Progressor;
        case NormalCapture(_, _, _, _), ChameleonCapture(_, _, _, _), Promotion(_, _, _), PromotionWithCapture(_, _, _, _):
            return true;
        case Castling(_, _):
            return false;
    }
}