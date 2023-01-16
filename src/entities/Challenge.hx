package entities;

import net.shared.PieceColor.opposite;
import services.Storage;
import net.shared.dataobj.ChallengeData;
import struct.ChallengeParams;

class Challenge 
{
    public var id:Int;
    public var params:ChallengeParams;
    public var ownerLogin:String;    

    public function isDirect():Bool
    {
        switch params.type 
        {
            case Direct(_):
                return true;
            default:
                return false;
        }
    }

    public function toChallengeData():ChallengeData
    {
        var info:ChallengeData = new ChallengeData();
        info.id = id;
        info.serializedParams = params.serialize();
        info.ownerLogin = ownerLogin;
        info.ownerELO = Storage.loadPlayerData(ownerLogin).getELO(params.timeControl.getType());
        return info;
    }

    public function isCompatibleWith(challenge:Challenge):Bool
    {
        var thisParams:ChallengeParams = this.params;
        var anotherParams:ChallengeParams = challenge.params;

        var differentOwners:Bool = challenge.ownerLogin != this.ownerLogin;
        var matchmakingEnabled:Bool = anotherParams.type == Public && thisParams.type == Public;
        var bracketsAgree:Bool = anotherParams.rated == thisParams.rated;
        var timeControlsAgree:Bool = anotherParams.timeControl.incrementSecs == thisParams.timeControl.incrementSecs && anotherParams.timeControl.startSecs == thisParams.timeControl.startSecs;
        var colorsAgree:Bool = anotherParams.acceptorColor == null || thisParams.acceptorColor == null || anotherParams.acceptorColor == opposite(anotherParams.acceptorColor);
        var startingSIPsAgree:Bool = (anotherParams.customStartingSituation == null && thisParams.customStartingSituation == null) || anotherParams.customStartingSituation != null && thisParams.customStartingSituation != null && anotherParams.customStartingSituation.getHash() == thisParams.customStartingSituation.getHash();
        
        return differentOwners && matchmakingEnabled && colorsAgree && startingSIPsAgree && bracketsAgree && timeControlsAgree;
    }

    public function isEquivalentTo(challenge:Challenge):Bool 
    {
        var thisParams:ChallengeParams = this.params;
        var anotherParams:ChallengeParams = challenge.params;
        
        var sameOwners:Bool = challenge.ownerLogin.toLowerCase() == this.ownerLogin.toLowerCase();
        var sameType:Bool = switch challenge.params.type 
        {
            case Public: params.type == Public;
            case ByLink: params.type == ByLink;
            case Direct(calleeRef1): switch params.type 
            {
                case Direct(calleeRef2): calleeRef2 == calleeRef1;
                default: false;
            }
        }
        var sameBrackets:Bool = anotherParams.rated == thisParams.rated;
        var sameTCs:Bool = anotherParams.timeControl.incrementSecs == thisParams.timeControl.incrementSecs && anotherParams.timeControl.startSecs == thisParams.timeControl.startSecs;
        var sameColors:Bool = (anotherParams.acceptorColor == null && thisParams.acceptorColor == null) || anotherParams.acceptorColor == anotherParams.acceptorColor;
        var sameSSIPs:Bool = (anotherParams.customStartingSituation == null && thisParams.customStartingSituation == null) || anotherParams.customStartingSituation != null && thisParams.customStartingSituation != null && anotherParams.customStartingSituation.getHash() == thisParams.customStartingSituation.getHash();
        
        return sameOwners && sameType && sameBrackets && sameTCs && sameColors && sameSSIPs;
    }

    public function new(id:Int, params:ChallengeParams, ownerLogin:String) 
    {
        this.id = id;
        this.params = params;
        this.ownerLogin = ownerLogin;
    }
}