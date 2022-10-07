package struct;

import net.shared.PieceType;
import net.shared.PieceColor;
import haxe.ds.Vector;

abstract PieceArrangement(Vector<Vector<Null<Piece>>>)
{
    public static function defaultStarting():PieceArrangement
    {
        var pieces:PieceArrangement = new PieceArrangement();

        pieces.set(new HexCoords(0, 0), new Piece(Dominator, Black));
        pieces.set(new HexCoords(1, 0), new Piece(Liberator, Black));
        pieces.set(new HexCoords(2, 0), new Piece(Aggressor, Black));
        pieces.set(new HexCoords(3, 0), new Piece(Defensor, Black));
        pieces.set(new HexCoords(4, 0), new Piece(Intellector, Black));
        pieces.set(new HexCoords(5, 0), new Piece(Defensor, Black));
        pieces.set(new HexCoords(6, 0), new Piece(Aggressor, Black));
        pieces.set(new HexCoords(7, 0), new Piece(Liberator, Black));
        pieces.set(new HexCoords(8, 0), new Piece(Dominator, Black));
        pieces.set(new HexCoords(0, 1), new Piece(Progressor, Black));
        pieces.set(new HexCoords(2, 1), new Piece(Progressor, Black));
        pieces.set(new HexCoords(4, 1), new Piece(Progressor, Black));
        pieces.set(new HexCoords(6, 1), new Piece(Progressor, Black));
        pieces.set(new HexCoords(8, 1), new Piece(Progressor, Black));

        pieces.set(new HexCoords(0, 5), new Piece(Progressor, White));
        pieces.set(new HexCoords(2, 5), new Piece(Progressor, White));
        pieces.set(new HexCoords(4, 5), new Piece(Progressor, White));
        pieces.set(new HexCoords(6, 5), new Piece(Progressor, White));
        pieces.set(new HexCoords(8, 5), new Piece(Progressor, White));
        pieces.set(new HexCoords(0, 6), new Piece(Dominator, White));
        pieces.set(new HexCoords(1, 5), new Piece(Liberator, White));
        pieces.set(new HexCoords(2, 6), new Piece(Aggressor, White));
        pieces.set(new HexCoords(3, 5), new Piece(Defensor, White));
        pieces.set(new HexCoords(4, 6), new Piece(Intellector, White));
        pieces.set(new HexCoords(5, 5), new Piece(Defensor, White));
        pieces.set(new HexCoords(6, 6), new Piece(Aggressor, White));
        pieces.set(new HexCoords(7, 5), new Piece(Liberator, White));
        pieces.set(new HexCoords(8, 6), new Piece(Dominator, White));

        return pieces;
    }

    public static function emptyArrangement():PieceArrangement
    {
        return new PieceArrangement();
    }

    public function empty(coords:HexCoords):Bool
    {
        return get(coords) == null;
    }

    public function is(coords:HexCoords, type:PieceType, color:PieceColor):Bool
    {
        return type != null && color != null && typeAt(coords) == type && colorAt(coords) == color;
    }

    public function affectedByAura(coords:HexCoords):Bool
    {
        var pieceColor:PieceColor = colorAt(coords);
        if (pieceColor == null)
            return false;

        for (nearbyCoords in coords.lateralSurroundings())
            if (is(nearbyCoords, Intellector, pieceColor))
                return true;

        return false;
    }

    public function typeAt(coords:HexCoords):Null<PieceType>  
    {
        var piece:Null<Piece> = get(coords);
        return piece != null? piece.type : null;
    }

    public function colorAt(coords:HexCoords):Null<PieceColor>  
    {
        var piece:Null<Piece> = get(coords);
        return piece != null? piece.color : null;
    }

    public function get(coords:HexCoords):Null<Piece> 
    {
        return this[coords.i][coords.j];
    }

    public function set(coords:HexCoords, value:Null<Piece>)
    {
        this[coords.i][coords.j] = value;
    }

    private function new() 
    {
        this = new Vector(9);
        for (i in 0...9)
            this[i] = new Vector(i % 2 == 0? 7 : 6);
    }
}