package;

enum FigureType
{
    Progressor;
    Aggressor;
    Dominator;
    Liberator;
    Defensor;
    Intellector;
}

enum Color
{
    White;
    Black;
}

typedef Figure = {type:FigureType, color:Color};

class Game
{
    public var id:Int;
    public var whiteLogin:String;
    public var blackLogin:String;
    public var whiteTurn:Bool;
    public var field:Array<Array<Null<Figure>>>;
    public var log:String;

    public function move(fromI, fromJ, toI, toJ):Null<Color>
    {
        var from = field[fromJ][fromI];
        var to = field[toJ][toI];
        field[toJ][toI] = from;
        if (to != null && ((from.type == Intellector && to.type == Defensor) || (from.type == Defensor && to.type == Intellector)) && from.color == to.color)
            field[fromJ][fromI] = to;
        else 
            field[fromJ][fromI] = null;
        log += '$fromI$fromJ$toI$toJ;\n';
        whiteTurn = !whiteTurn;
        return (to != null && to.type == Intellector && from.color != to.color)? from.color : null;
    }

    public function arrangePieces()
    {
        field = [for (j in 0...7) [for (i in 0...9) null]];
        field[0][0] = {type: Dominator, color: Black};
        field[0][1] = {type: Liberator, color: Black};
        field[0][2] = {type: Aggressor, color: Black};
        field[0][3] = {type: Defensor, color: Black};
        field[0][4] = {type: Intellector, color: Black};
        field[0][5] = {type: Defensor, color: Black};
        field[0][6] = {type: Aggressor, color: Black};
        field[0][7] = {type: Liberator, color: Black};
        field[0][8] = {type: Dominator, color: Black};
        field[1][0] = {type: Progressor, color: Black};
        field[1][2] = {type: Progressor, color: Black};
        field[1][4] = {type: Progressor, color: Black};
        field[1][6] = {type: Progressor, color: Black};
        field[1][8] = {type: Progressor, color: Black};

        field[6][0] = {type: Dominator, color: White};
        field[5][1] = {type: Liberator, color: White};
        field[6][2] = {type: Aggressor, color: White};
        field[5][3] = {type: Defensor, color: White};
        field[6][4] = {type: Intellector, color: White};
        field[5][5] = {type: Defensor, color: White};
        field[6][6] = {type: Aggressor, color: White};
        field[5][7] = {type: Liberator, color: White};
        field[6][8] = {type: Dominator, color: White};
        field[5][0] = {type: Progressor, color: White};
        field[5][2] = {type: Progressor, color: White};
        field[5][4] = {type: Progressor, color: White};
        field[5][6] = {type: Progressor, color: White};
        field[5][8] = {type: Progressor, color: White};
    }

    public function new(whiteLogin, blackLogin) 
    {
        id = Main.currID;
        this.whiteLogin = whiteLogin;
        this.blackLogin = blackLogin;
        whiteTurn = true;
        log = '$whiteLogin : $blackLogin;\n';
        arrangePieces();
    }
}