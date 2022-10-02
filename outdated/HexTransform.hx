package;

import Game.Figure;
import Game.FigureType;

class HexTransform
{
    public var i:Int;
    public var j:Int;
    public var former:Null<Figure>;
    public var latter:Null<Figure>;

    public function new(i, j, former, latter) 
    {
        this.i = i;
        this.j = j;
        this.former = former;
        this.latter = latter;
    }
}