package struct;

import utils.MathUtils;
import net.shared.PieceColor;

enum ChallengeType
{
    Public;
    ByLink;
    Direct(calleeRef:String);
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

    public function compatibilityIndicator():Null<String> 
    {
        if (type != Public)
            return null;

        var colorStr = switch acceptorColor 
        {
            case null: "";
            case White: "w";
            case Black: "b";
        }

        var sitStr = customStartingSituation == null? "" : customStartingSituation.serialize();
        var ratedStr = rated? "t" : "";

        return colorStr + ";" + timeControl.startSecs + ";" + timeControl.incrementSecs + ";" + sitStr + ";" + ratedStr;
    }

    public function compatibleIndicators():Array<String> 
    {
        if (type != Public)
            return [];
        
        var sitStr = customStartingSituation == null? "" : customStartingSituation.serialize();
        var ratedStr = rated? "t" : "";

        var mainPart:String = ";" + timeControl.startSecs + ";" + timeControl.incrementSecs + ";" + sitStr + ";" + ratedStr;

        return switch acceptorColor 
        {
            case null: ["w" + mainPart, "b" + mainPart, mainPart];
            case White: ["b" + mainPart, mainPart];
            case Black: ["w" + mainPart, mainPart];
        }
    }

    public function serialize():String
    {
        var typeStr:String = switch type 
        {
            case Public: "p";
            case ByLink: "l";
            case Direct(calleeLogin): calleeLogin;
        }

        var colorStr = switch acceptorColor 
        {
            case null: "";
            case White: "w";
            case Black: "b";
        }

        var sitStr = customStartingSituation == null? "" : customStartingSituation.serialize();
        var ratedStr = rated? "t" : "";

        return timeControl.startSecs + ";" + timeControl.incrementSecs + ";" + typeStr + ";" + colorStr + ";" + sitStr + ";" + ratedStr;
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