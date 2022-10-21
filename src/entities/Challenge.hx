package entities;

import services.Storage;
import net.shared.ChallengeData;
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

    public function new(id:Int, params:ChallengeParams, ownerLogin:String) 
    {
        this.id = id;
        this.params = params;
        this.ownerLogin = ownerLogin;
    }
}