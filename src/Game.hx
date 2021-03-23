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

enum MatchResult
{
    Mate(winner:Color);
    Breakthrough(winner:Color);
    Resignation(winner:Color);
    Timeout(winner:Color);
    Abandon(winner:Color);
    ThreefoldRepetition;
    HundredMoveRule;
    DrawAgreement;
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

    public var turn:Int;
    public var lastActualTimestamp:Float;
    public var secsPerTurn:Int;
    public var secsLeftWhite:Int;
    public var secsLeftBlack:Int;

    private var positionCount:Map<String, Int> = [];
    private var silentMovesCount:Int = 0;

    public function move(fromI, fromJ, toI, toJ, ?morphInto:FigureType)
    {
        var from = field[fromJ][fromI];
        var to = field[toJ][toI];

        var isCastle = to != null && ((from.type == Intellector && to.type == Defensor) || (from.type == Defensor && to.type == Intellector)) && from.color == to.color;

        field[toJ][toI] = from;

        if (morphInto != null)
            field[toJ][toI].type = morphInto;

        if (isCastle)
            field[fromJ][fromI] = to;
        else 
            field[fromJ][fromI] = null;

        if (isCastle || (to == null && from.type != Progressor))
            silentMovesCount++;
        else 
            silentMovesCount = 0;

        if (morphInto != null)
            log += '$fromI$fromJ$toI$toJ${morphInto.getName()};\n';
        else 
            log += '$fromI$fromJ$toI$toJ;\n';

        if (turn > 2)
        {
            updateTimeLeft();
            incrementTime();
        }
        else if (turn == 2)
            lastActualTimestamp = Date.now().getTime();

        whiteTurn = !whiteTurn;
        turn++;

        var sPos = serializePosition();
        var samePosCount = positionCount.get(sPos);
        if (samePosCount == null)
            positionCount[sPos] = 1;
        else
            positionCount[sPos] = ++samePosCount;

        if (samePosCount == 3)
            Main.endGame(ThreefoldRepetition, this);
        else if (to != null && to.type == Intellector && from.color != to.color)
            Main.endGame(Mate(from.color), this);
        else if (from.type == Intellector && isFinalRel(toI, toJ, from.color))
            Main.endGame(Breakthrough(from.color), this);
        else if (silentMovesCount == 100)
            Main.endGame(HundredMoveRule, this);
    }

    public function updateTimeLeft()
    {
        var ts = Date.now().getTime();
        var secondsElapsed = Math.round((ts - lastActualTimestamp) / 1000);
        if (whiteTurn)
            secsLeftWhite -= secondsElapsed;
        else 
            secsLeftBlack -= secondsElapsed;
        lastActualTimestamp = ts;

        if (secsLeftWhite <= 0)
            Main.endGame(Timeout(Black), this);
        else if (secsLeftBlack <= 0)
            Main.endGame(Timeout(White), this);
    }

    private function incrementTime()
    {
        if (whiteTurn)
            secsLeftWhite += secsPerTurn;
        else 
            secsLeftBlack += secsPerTurn;
    }

    private function isFinalRel(i:Int, j:Int, color:Color):Bool
    {
        if (color == White)
            return j == 0 && i % 2 == 0;
        else 
            return j == 6 && i % 2 == 0;
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

    private function serializePosition():String
    {
        var s = whiteTurn? "w" : "b";
        for (i in 0...9)
            for (j in 0...7)
            {
                var fig = field[j][i];
                if (fig != null)
                    s += '$i$j${fig.type.getName().charAt(1)}${fig.color == White? "w" : "b"}';
            }
        return s;
    }

    public function new(whiteLogin, blackLogin, secStart:Int, secBonus:Int) 
    {
        id = Main.currID;
        this.whiteLogin = whiteLogin;
        this.blackLogin = blackLogin;
        whiteTurn = true;
        log = '$whiteLogin : $blackLogin;\n';
        turn = 1;
        secsLeftWhite = secStart;
        secsLeftBlack = secStart;
        secsPerTurn = secBonus;
        arrangePieces();
    }
}