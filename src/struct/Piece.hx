package struct;

import net.shared.PieceColor;
import net.shared.PieceType;

class Piece
{
    public final type:PieceType;
    public final color:PieceColor;

    public function new(type:PieceType, color:PieceColor)
    {
        this.type = type;
        this.color = color;
    }
}