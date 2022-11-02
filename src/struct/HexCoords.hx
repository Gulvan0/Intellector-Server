package struct;

import net.shared.PieceColor;
import net.shared.PieceType;
import struct.Direction;

class HexCoords
{
    public final i:Int;
    public final j:Int;

    public function isFinal(color:PieceColor) 
    {
        if (color == White)
            return j == 0;
        else
            return j == 6;
    }

    public function equals(other:HexCoords):Bool 
    {
        return other.i == i && other.j == j;
    }

    public function isLiberatorJumpAway(departure:HexCoords) 
    {
        for (dir in [Up, UpLeft, UpRight, Down, DownLeft, DownRight])
        {
            var destination:HexCoords = departure.step(dir).step(dir);
            if (destination.isValid() && equals(destination))
                return true;
        }
                
        return false;
    }

    public function isLaterallyNear(departure:HexCoords) 
    {
        return isOneStepAway(departure, [Up, UpLeft, UpRight, Down, DownLeft, DownRight]);
    }

    public function isForwardStepAway(departure:HexCoords, color:PieceColor) 
    {
        var forwardDirections:Array<Direction> = color == White? [Up, UpLeft, UpRight] : [Down, DownLeft, DownRight];
        return isOneStepAway(departure, forwardDirections);
    }

    public function isOneStepAway(departure:HexCoords, checkedDirections:Array<Direction>) 
    {
        for (dir in checkedDirections)
        {
            var neighbour:HexCoords = step(dir);
            if (neighbour.isValid() && neighbour.equals(departure))
                return true;
        }
                
        return false;
    }

    public function lateralSurroundings():Array<HexCoords>
    {
        var result:Array<HexCoords> = [];

        for (dir in [Up, UpLeft, UpRight, Down, DownLeft, DownRight])
        {
            var neighbour:HexCoords = step(dir);
            if (neighbour.isValid())
                result.push(neighbour);
        }

        return result;
    }

    public function step(dir:Direction):HexCoords
    {
        return switch dir 
        {
            case Up: 
                new HexCoords(i, j - 1);
            case UpLeft:
                new HexCoords(i - 1, i % 2 == 0? j - 1 : j);
            case UpRight:
                new HexCoords(i + 1, i % 2 == 0? j - 1 : j);
            case Down:
                new HexCoords(i, j + 1);
            case DownLeft:
                new HexCoords(i - 1, i % 2 == 1? j + 1 : j);
            case DownRight:
                new HexCoords(i + 1, i % 2 == 1? j + 1 : j);
            case AgrUpLeft:
                new HexCoords(i - 1, i % 2 == 0? j - 2 : j - 1);
            case AgrUpRight:
                new HexCoords(i + 1, i % 2 == 0? j - 2 : j - 1);
            case AgrDownLeft:
                new HexCoords(i - 1, i % 2 == 1? j + 2 : j + 1);
            case AgrDownRight:
                new HexCoords(i + 1, i % 2 == 1? j + 2 : j + 1);
            case AgrLeft:
                new HexCoords(i - 2, j);
            case AgrRight:
                new HexCoords(i + 2, j);
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

    public static function fromScalarCoord(t:Int):HexCoords 
    {
        var det:Int = t % 9;
        if (det < 5)
            return new HexCoords(det * 2, Std.int(t / 9));
        else
            return new HexCoords(det * 2 - 9, Std.int(t / 9));
    }

    public function new(i:Int, j:Int)
    {
        this.i = i;
        this.j = j;
    }
}