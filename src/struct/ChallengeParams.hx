package struct;

import net.shared.PieceColor;

enum ChallengeType
{
    Public;
    ByLink;
    Direct(calleeLogin:String);
}

class ChallengeParams 
{
    public var type:ChallengeType;
    public var timeControl:TimeControl;
    public var acceptorColor:Null<PieceColor>;
    public var customStartingSituation:Null<Situation>;
    public var rated:Bool;

    public static function deserialize(s:String):ChallengeParams
    {
        var splitted:Array<String> = s.split(";");
        var timeControl:TimeControl = new TimeControl(Std.parseInt(splitted[0]), Std.parseInt(splitted[1]));
        var type:ChallengeType = splitted[2] == "p"? Public : splitted[2] == "l"? ByLink : Direct(splitted[2].toLowerCase());
        var acceptorColor:Null<PieceColor> = splitted[3] == "w"? White : splitted[3] == "b"? Black : null;
        var customStartingSituation:Null<Situation> = splitted[4] == ""? null : Situation.deserialize(splitted[4]);
        var rated:Bool = splitted[5] == "t";
        return new ChallengeParams(timeControl, type, acceptorColor, customStartingSituation, rated);
    }

    private function isValid():Bool
    {
        return !rated || (customStartingSituation == null && acceptorColor == null);
    }

    public function new(timeControl:TimeControl, type:ChallengeType, ?acceptorColor:Null<PieceColor>, ?customStartingSituation:Null<Situation>, ?rated:Bool = false)
    {
        this.timeControl = timeControl;
        this.type = type;
        this.acceptorColor = acceptorColor;
        this.customStartingSituation = customStartingSituation;
        this.rated = rated;
    }
}