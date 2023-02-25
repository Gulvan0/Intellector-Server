package struct;

import net.shared.TimeControl;
import net.shared.board.Situation;
import net.shared.utils.MathUtils;
import net.shared.PieceColor;

enum ChallengeType
{
    Public;
    ByLink;
    Direct(calleeRef:String);
    ToBot(botHandle:String);
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
        var timeControl:TimeControl = TimeControl.construct(Std.parseInt(splitted[0]), Std.parseInt(splitted[1]));
        var type:ChallengeType = splitted[2] == "p"? Public : splitted[2] == "l"? ByLink : splitted[2].charAt(0) == "+"? ToBot(splitted[2].substr(1)) : Direct(splitted[2].toLowerCase());
        var acceptorColor:Null<PieceColor> = splitted[3] == "w"? White : splitted[3] == "b"? Black : null;
        var customStartingSituation:Null<Situation> = splitted[4] == ""? null : Situation.deserialize(splitted[4]);
        var rated:Bool = splitted[5] == "t";
        return new ChallengeParams(timeControl, type, acceptorColor, customStartingSituation, rated);
    }

    public function serialize():String
    {
        var timeStr:String = switch timeControl 
        {
            case Correspondence: '0;0';
            case Fischer(startSecs, incrementSecs): startSecs + ";" + incrementSecs;
            case FixedTimePerMove(secsPerMove): "0;" + secsPerMove;
        }

        var typeStr:String = switch type 
        {
            case Public: "p";
            case ByLink: "l";
            case Direct(calleeLogin): calleeLogin;
            case ToBot(botHandle): "+" + botHandle;
        }

        var colorStr = switch acceptorColor 
        {
            case null: "";
            case White: "w";
            case Black: "b";
        }

        var sitStr = customStartingSituation == null? "" : customStartingSituation.serialize();
        var ratedStr = rated? "t" : "";

        return timeStr + ";" + typeStr + ";" + colorStr + ";" + sitStr + ";" + ratedStr;
    }

    private function isValid():Bool
    {
        return !rated || (customStartingSituation == null && acceptorColor == null);
    }

    public function calculateActualAcceptorColor() 
    {
        if (acceptorColor != null)
            return acceptorColor;
        else
            return MathUtils.bernoulli(0.5)? White : Black;    
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