package net.shared.openings;

class Opening
{
    public final id:Int;
    public final shownToPlayersName:String;
    public final realName:String;
    public final isContinuation:Bool;

    public function renderName(hideRealName:Bool):String
    {
        return hideRealName? shownToPlayersName : realName;
    }

    public function withContinuation(plyStr:String, plyNum:Int):Opening
    {
        var newHiddenName:String = realName + " ";

        if (!isContinuation)
            newHiddenName += "...";

        newHiddenName += '$plyNum. $plyStr';

        var newShownToPlayersName:String = realName == shownToPlayersName? newHiddenName : shownToPlayersName;

        return new Opening(newShownToPlayersName, newHiddenName, true);
    }

    public function new(id:Int, shownToPlayersName:String, realName:String, ?isContinuation:Bool = false) 
    {
        this.id = id;
        this.shownToPlayersName = shownToPlayersName;
        this.realName = realName;
        this.isContinuation = isContinuation;
    }
}