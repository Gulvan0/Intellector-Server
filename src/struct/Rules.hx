package struct;

import net.shared.PieceColor;
import net.shared.PieceType;
import struct.Direction;
import struct.HexCoords;

class Rules 
{
    private static function isPathAllowed(pieces:PieceArrangement, turnColor:PieceColor, from:HexCoords, to:HexCoords):Bool
    {
        var movingPiece:PieceType = pieces.typeAt(from);
        if (movingPiece == null)
            return false;

        switch movingPiece 
        {
            case Progressor:
                return to.isForwardStepAway(from, turnColor);
            case Aggressor:
                for (dir in [AgrLeft, AgrUpLeft, AgrUpRight, AgrRight, AgrDownLeft, AgrDownRight])
                {
                    var next:HexCoords = from.step(dir);

                    while (next.isValid())
                        if (next.equals(to))
                            return true;
                        else if (pieces.empty(next))
                            next = next.step(dir);
                        else
                            break;
                }
                return false;
            case Dominator:
                for (dir in [Up, UpLeft, UpRight, Down, DownLeft, DownRight])
                {
                    var next:HexCoords = from.step(dir);

                    while (next.isValid())
                        if (next.equals(to))
                            return true;
                        else if (pieces.empty(next))
                            next = next.step(dir);
                        else
                            break;
                }
                return false;
            case Liberator:
                return to.isLaterallyNear(from) || to.isLiberatorJumpAway(from);
            case Defensor:
                return to.isLaterallyNear(from);
            case Intellector:
                return to.isLaterallyNear(from);
        }
    }

    private static function isCaptureAllowed(movingPiece:PieceType, from:HexCoords, to:HexCoords):Bool
    {
        switch movingPiece 
        {
            case Liberator:
                return to.isLiberatorJumpAway(from);
            case Intellector:
                return false;
            default:
                return true;
        }
    }

    public static function isPlyPossible(ply:Ply, pieces:PieceArrangement, turnColor:PieceColor):Bool 
    {
        switch ply 
        {
            case NormalMove(from, to, movingPiece):
                return pieces.empty(to) && pieces.is(from, movingPiece, turnColor) && (!to.isFinal(turnColor) || movingPiece != Progressor) && isPathAllowed(pieces, turnColor, from, to);
            case NormalCapture(from, to, capturingPiece, capturedPiece):
                return pieces.is(to, capturedPiece, opposite(turnColor)) && pieces.is(from, capturingPiece, turnColor) && isPathAllowed(pieces, turnColor, from, to) && isCaptureAllowed(capturingPiece, from, to);
            case ChameleonCapture(from, to, capturingPiece, capturedPiece):
                return pieces.is(to, capturedPiece, opposite(turnColor)) && pieces.is(from, capturingPiece, turnColor) && pieces.affectedByAura(from) && capturedPiece != capturingPiece && capturedPiece != Intellector && isPathAllowed(pieces, turnColor, from, to) && isCaptureAllowed(capturingPiece, from, to);
            case Promotion(from, to, promotedTo):
                return pieces.empty(to) && pieces.is(from, Progressor, turnColor) && promotedTo != Intellector && promotedTo != Progressor && to.isFinal(turnColor) && isPathAllowed(pieces, turnColor, from, to);
            case PromotionWithCapture(from, to, capturedPiece, promotedTo):
                return pieces.is(from, capturedPiece, opposite(turnColor)) && pieces.is(from, Progressor, turnColor) && promotedTo != Intellector && promotedTo != Progressor && to.isFinal(turnColor) && isPathAllowed(pieces, turnColor, from, to) && isCaptureAllowed(Progressor, from, to); 
            case Castling(from, to):
                return ((pieces.is(from, Intellector, turnColor) && pieces.is(to, Defensor, turnColor)) || (pieces.is(to, Intellector, turnColor) && pieces.is(from, Defensor, turnColor))) && to.isLaterallyNear(from);
        }
    }
}