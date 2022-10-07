package struct;

import struct.Ply;
import net.shared.Outcome;
import net.shared.PieceColor;
import net.shared.PieceType;

enum PerformPlyResult
{
    NormalPlyPerformed(ply:Ply);
    ProgressivePlyPerformed(ply:Ply);
    MateReached;
    BreakthroughReached;
    FailedToPerform;
}

class Situation
{
    private var pieces:PieceArrangement;
    private var turnColor:PieceColor;

    public static function defaultStarting():Situation
    {
        return new Situation(PieceArrangement.defaultStarting(), White);
    }

    public static function deserialize(sip:String):Null<Situation>
    {
        var pieces:PieceArrangement = PieceArrangement.emptyArrangement();
        var turnColor:PieceColor = colorByLetter(sip.charAt(0));

        var exclamationMarkPassed:Bool = false;
        var ci = 1;
        while (ci < sip.length)
        {
            if (sip.charCodeAt(ci) == "!".code)
            {
                if (exclamationMarkPassed)
                    return null; //Exactly one exclamation mark per SIP expected

                exclamationMarkPassed = true;
                ci++;
                continue;
            }
            
            var scalarCoord:Int = sip.charCodeAt(ci) - 64;
            if (scalarCoord < 0 || scalarCoord >= 59)
                return null; //Invalid hex location

            var pieceType:Null<PieceType> = pieceByLetter(sip.charAt(ci + 1));
            var pieceColor:PieceColor = exclamationMarkPassed? Black : White;

            if (pieceType != null)
                pieces.set(HexCoords.fromScalarCoord(scalarCoord), new Piece(pieceType, pieceColor));
            else
                return null; //Invalid PieceType code

            ci += 2;
        }

        return new Situation(pieces, turnColor);
    }

    public function performPly(from:HexCoords, to:HexCoords, morphInto:Null<PieceType>):PerformPlyResult
    {
        var ply:Ply = Ply.construct(pieces, from, to, morphInto);

        if (!Rules.isPlyPossible(ply, pieces, turnColor))
            return FailedToPerform;
        else if (Ply.isMating(ply))
            return MateReached;
        else if (Ply.isBreakthrough(ply, pieces, turnColor))
            return BreakthroughReached;
        else if (Ply.isProgressive(ply))
            return ProgressivePlyPerformed(ply);
        else
            return NormalPlyPerformed(ply);

    }

    public function revertPly(ply:Ply)
    {
        turnColor = opposite(turnColor);

        switch ply 
        {
            case NormalMove(from, to, _):
                pieces.set(from, pieces.get(to));
                pieces.set(to, null);
            case NormalCapture(from, to, _, capturedPiece):
                pieces.set(from, pieces.get(to));
                pieces.set(to, new Piece(capturedPiece, opposite(turnColor)));
            case ChameleonCapture(from, to, capturingPiece, capturedPiece):
                pieces.set(from, new Piece(capturingPiece, turnColor));
                pieces.set(to, new Piece(capturedPiece, opposite(turnColor)));
            case Promotion(from, to, _):
                pieces.set(from, new Piece(Progressor, turnColor));
                pieces.set(to, null);
            case PromotionWithCapture(from, to, capturedPiece, _):
                pieces.set(from, new Piece(Progressor, turnColor));
                pieces.set(to, new Piece(capturedPiece, opposite(turnColor)));
            case Castling(from, to):
                var tmp:Piece = pieces.get(from);
                pieces.set(from, pieces.get(to));
                pieces.set(to, tmp);
        }
    }

    private function new(pieces:PieceArrangement, turnColor:PieceColor)
    {
        this.pieces = pieces;
        this.turnColor = turnColor;
    }
}