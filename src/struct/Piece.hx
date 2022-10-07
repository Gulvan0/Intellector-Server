package struct;

import net.shared.PieceColor;
import net.shared.PieceType;

class Piece
{
    public var type(default, null):PieceType;
    public var color(default, null):PieceColor;

    public function new(type:PieceType, color:PieceColor)
    {
        this.type = type;
        this.color = color;
    }
}