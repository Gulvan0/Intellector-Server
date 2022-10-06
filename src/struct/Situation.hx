package struct;

import net.shared.PieceColor;
import net.shared.PieceType;

enum Direction
{
    Up;
    UpLeft;
    UpRight;
    Down;
    DownLeft;
    DownRight;
    AgrUpLeft;
    AgrUpRight;
    AgrDownLeft;
    AgrDownRight;
    AgrLeft;
    AgrRight;
}

class TwoDimCoords
{
    public var i:Int;
    public var j:Int;

    public function isFinal(color:PieceColor) 
    {
        if (color == White)
            return j == 0;
        else
            return j == 6;
    }

    public function equals(other:TwoDimCoords):Bool 
    {
        return other.i == i && other.j == j;
    }

    public function isLiberatorJumpAway(departure:TwoDimCoords) 
    {
        for (dir in [Up, UpLeft, UpRight, Down, DownLeft, DownRight])
            if (equals(departure.step(dir).step(dir)))
                return true;
        return false;
    }

    public function isLaterallyNear(departure:TwoDimCoords) 
    {
        return isOneStepAway(departure, [Up, UpLeft, UpRight, Down, DownLeft, DownRight]);
    }

    public function isForwardStepAway(departure:TwoDimCoords, color:PieceColor) 
    {
        var forwardDirections:Array<Direction> = color == White? [Up, UpLeft, UpRight] : [Down, DownLeft, DownRight];
        return isOneStepAway(departure, forwardDirections);
    }

    public function isOneStepAway(departure:TwoDimCoords, checkedDirections:Array<Direction>) 
    {
        for (dir in checkedDirections)
            if (equals(departure.step(dir)))
                return true;
        return false;
    }

    public function step(dir:Direction):TwoDimCoords
    {
        return switch dir 
        {
            case Up: 
                new TwoDimCoords(i, j - 1);
            case UpLeft:
                new TwoDimCoords(i - 1, i % 2 == 0? j - 1 : j);
            case UpRight:
                new TwoDimCoords(i + 1, i % 2 == 0? j - 1 : j);
            case Down:
                new TwoDimCoords(i, j + 1);
            case DownLeft:
                new TwoDimCoords(i - 1, i % 2 == 1? j + 1 : j);
            case DownRight:
                new TwoDimCoords(i + 1, i % 2 == 1? j + 1 : j);
            case AgrUpLeft:
                new TwoDimCoords(i - 1, i % 2 == 0? j - 2 : j - 1);
            case AgrUpRight:
                new TwoDimCoords(i + 1, i % 2 == 0? j - 2 : j - 1);
            case AgrDownLeft:
                new TwoDimCoords(i - 1, i % 2 == 1? j + 2 : j + 1);
            case AgrDownRight:
                new TwoDimCoords(i + 1, i % 2 == 1? j + 2 : j + 1);
            case AgrLeft:
                new TwoDimCoords(i - 2, j);
            case AgrRight:
                new TwoDimCoords(i + 2, j);
        }
    }

    public function isValid():Bool
    {
        if (i % 2 == 0)
            return i >= 0 && i <= 8 && j >= 0 && j <= 6;
        else
            return i >= 0 && i <= 8 && j >= 0 && j <= 5;
    }

    public function toScalarCoord():Int
    {
        if (i % 2 == 0)
            return 9 * j + Std.int(i / 2);
        else
            return 9 * j + Std.int(i / 2) + 5;
    }

    public static function fromScalarCoord(t:Int):TwoDimCoords 
    {
        var det:Int = t % 9;
        if (det > 4)
            return new TwoDimCoords(det * 2, Std.int(det / 9));
        else
            return new TwoDimCoords(det * 2 - 9, Std.int(det / 9));
    }

    public function new(i:Int, j:Int)
    {
        this.i = i;
        this.j = j;
    }
}

class Piece
{
    public var type:PieceType;
    public var color:PieceColor;

    public function new(type:PieceType, color:PieceColor)
    {
        this.type = type;
        this.color = color;
    }
}

class Situation
{
    private var pieces:Array<Null<Piece>>;
    private var turnColor:PieceColor;

    public static function deserialize(sip:String):Null<Situation>
    {
        var pieces:Array<Null<Piece>> = [];
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
                pieces[scalarCoord] = new Piece(pieceType, pieceColor);
            else
                return null; //Invalid PieceType code

            ci += 2;
        }

        return new Situation(pieces, turnColor);
    }

    public static function defaultStarting():Situation
    {
        var pieces:Array<Null<Piece>> = [];

        pieces[0] = new Piece(Dominator, Black);
        pieces[1] = new Piece(Aggressor, Black);
        pieces[2] = new Piece(Intellector, Black);
        pieces[3] = new Piece(Aggressor, Black);
        pieces[4] = new Piece(Dominator, Black);
        pieces[5] = new Piece(Liberator, Black);
        pieces[6] = new Piece(Defensor, Black);
        pieces[7] = new Piece(Defensor, Black);
        pieces[8] = new Piece(Liberator, Black);
        pieces[9] = new Piece(Progressor, Black);
        pieces[10] = new Piece(Progressor, Black);
        pieces[11] = new Piece(Progressor, Black);
        pieces[12] = new Piece(Progressor, Black);
        pieces[13] = new Piece(Progressor, Black);

        pieces[45] = new Piece(Progressor, White);
        pieces[46] = new Piece(Progressor, White);
        pieces[47] = new Piece(Progressor, White);
        pieces[48] = new Piece(Progressor, White);
        pieces[49] = new Piece(Progressor, White);
        pieces[50] = new Piece(Liberator, White);
        pieces[51] = new Piece(Defensor, White);
        pieces[52] = new Piece(Defensor, White);
        pieces[53] = new Piece(Liberator, White);
        pieces[54] = new Piece(Dominator, White);
        pieces[55] = new Piece(Aggressor, White);
        pieces[56] = new Piece(Intellector, White);
        pieces[57] = new Piece(Aggressor, White);
        pieces[58] = new Piece(Dominator, White);

        return new Situation(pieces, White);
    }

    public function revertPly(ply:Ply)
    {
        if (turnColor == White)
            turnColor = Black;
        else
            turnColor = White;

        switch ply 
        {
            case NormalMove(from, to, _):
                pieces[from] = pieces[to];
                pieces[to] = null;
            case NormalCapture(from, to, _, capturedPiece):
                pieces[from] = pieces[to];
                pieces[to] = new Piece(capturedPiece, opposite(turnColor));
            case ChameleonCapture(from, to, _, capturingPiece):
                pieces[from] = new Piece(capturingPiece, turnColor);
                pieces[to] = new Piece(pieces[to].type, opposite(turnColor));
            case Promotion(from, to, _):
                pieces[from] = new Piece(Progressor, turnColor);
                pieces[to] = null;
            case PromotionWithCapture(from, to, capturedPiece, _):
                pieces[from] = new Piece(Progressor, turnColor);
                pieces[to] = new Piece(capturedPiece, opposite(turnColor));
            case Castling(from, to):
                var tmp:Piece = pieces[from];
                pieces[from] = pieces[to];
                pieces[to] = tmp;
        }
    }

    public function plyFromValidParams(from:Int, to:Int, morphInto:Null<PieceType>):Ply 
    {
        if (pieces[to] != null)
            if (pieces[from].color == pieces[to].color)
                return Castling(from, to);
            else if (morphInto == null)
                return NormalCapture(from, to, pieces[from].type, pieces[to].type);
            else if (pieces[from].type == Progressor)
                return PromotionWithCapture(from, to, pieces[to].type, morphInto);
            else
                return ChameleonCapture(from, to, pieces[from].type, pieces[from].type);
        else if (morphInto != null)
            return Promotion(from, to, morphInto);
        else
            return NormalMove(from, to, pieces[from].type);
    }

    public function isPlyProgressive(ply:Ply):Bool
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

    public function doesLeadToMate(from:Int, to:Int, morphInto:Null<PieceType>):Bool
    {
        return pieces[to].color != pieces[from].color && pieces[to].type == Intellector;
    }

    public function doesLeadToBreakthrough(from:Int, to:Int, morphInto:Null<PieceType>):Bool
    {
        return TwoDimCoords.fromScalarCoord(from).isFinal(pieces[from].color) && pieces[from].type == Intellector;
    }

    public function applyMove(from:Int, to:Int, morphInto:Null<PieceType>)
    {
        if (morphInto != null)
        {
            pieces[to] = new Piece(morphInto, pieces[from].color);
            pieces[from] = null;
        }
        else if (pieces[to] == null || pieces[to].color != pieces[from].color)
        {
            pieces[to] = pieces[from];
            pieces[from] = null;
        }
        else
        {
            var tmp:Piece = pieces[to];
            pieces[to] = pieces[from];
            pieces[from] = tmp;
        }

        if (turnColor == White)
            turnColor = Black;
        else
            turnColor = White;
    }

    private function checkHex(scalarCoord:Int, type:PieceType, color:PieceColor):Bool
    {
        return pieces[scalarCoord] != null && pieces[scalarCoord].color == color && pieces[scalarCoord].type == type;
    }

    private function isIntellectorNear(coords:TwoDimCoords, color:PieceColor):Bool
    {
        for (dir in [Up, UpLeft, UpRight, Down, DownLeft, DownRight])
        {
            var searchedCoords:TwoDimCoords = coords.step(dir);
            if (!searchedCoords.isValid())
                continue;

            if (checkHex(searchedCoords.toScalarCoord(), Intellector, color))
                return true;
        }
        return false;
    }

    private function isChameleonCorrect(from:TwoDimCoords, to:TwoDimCoords, morphInto:PieceType, turnColor:PieceColor) 
    {
        return isIntellectorNear(from, turnColor) && checkHex(to.toScalarCoord(), morphInto, opposite(turnColor)) && morphInto != Intellector && morphInto != pieces[from.toScalarCoord()].type;
    }

    public function isMovePossible(from:Int, to:Int, morphInto:Null<PieceType>):Bool
    {
        var fromCoords:TwoDimCoords = TwoDimCoords.fromScalarCoord(from);
        var toCoords:TwoDimCoords = TwoDimCoords.fromScalarCoord(to);

        if (from == to || !fromCoords.isValid() || !toCoords.isValid())
            return false;

        if (pieces[from] == null || pieces[from].color != turnColor)
            return false;

        switch pieces[from].type 
        {
            case Progressor:
                if (morphInto == null)
                    return toCoords.isForwardStepAway(fromCoords, turnColor) && toCoords.isFinal(turnColor);
                else if (morphInto == Intellector || morphInto == Progressor)
                    return false;
                else
                    return toCoords.isForwardStepAway(fromCoords, turnColor);

            case Defensor:
                if (morphInto != null)
                    return toCoords.isLaterallyNear(fromCoords) && isChameleonCorrect(fromCoords, toCoords, morphInto, turnColor);
                else if (pieces[to] != null && pieces[to].color == pieces[from].color && pieces[to].type != Intellector)
                    return false;
                else
                    return toCoords.isLaterallyNear(fromCoords);

            case Aggressor:
                if (morphInto != null && !isChameleonCorrect(fromCoords, toCoords, morphInto, turnColor))
                    return false;

                for (dir in [AgrLeft, AgrUpLeft, AgrUpRight, AgrRight, AgrDownLeft, AgrDownRight])
                {
                    var next:TwoDimCoords = fromCoords.step(dir);

                    while (next.isValid() && !next.equals(toCoords))
                        if (pieces[next.toScalarCoord()] != null)
                            break;
                        else
                            next = next.step(dir);

                    if (next.equals(toCoords))
                        return true;
                }

                return false;

            case Liberator:
                if (morphInto != null && !isChameleonCorrect(fromCoords, toCoords, morphInto, turnColor))
                    return false;
                    
                if (pieces[to] != null)
                    return toCoords.isLiberatorJumpAway(fromCoords) && pieces[to].color != pieces[from].color;
                else
                    return toCoords.isLiberatorJumpAway(fromCoords) || toCoords.isLaterallyNear(fromCoords);

            case Dominator:
                if (morphInto != null && !isChameleonCorrect(fromCoords, toCoords, morphInto, turnColor))
                    return false;

                for (dir in [Up, UpLeft, UpRight, Down, DownLeft, DownRight])
                {
                    var next:TwoDimCoords = fromCoords.step(dir);

                    while (next.isValid() && !next.equals(toCoords))
                        if (pieces[next.toScalarCoord()] != null)
                            break;
                        else
                            next = next.step(dir);

                    if (next.equals(toCoords))
                        return true;
                }

                return false;
                
            case Intellector:
                if (morphInto != null)
                    return false;
                else if (pieces[to] == null)
                    return toCoords.isLaterallyNear(fromCoords);
                else
                    return toCoords.isLaterallyNear(fromCoords) && pieces[to].type == Defensor && pieces[to].color == pieces[from].color;
        }
    }

    public function new(pieces:Array<Null<Piece>>, turnColor:PieceColor)
    {
        this.pieces = pieces;
        this.turnColor = turnColor;
    }
}