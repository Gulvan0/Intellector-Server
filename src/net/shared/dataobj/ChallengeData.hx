package net.shared.dataobj;

import net.shared.utils.PlayerRef;

class ChallengeData
{
    public var id:Int;
    public var params:ChallengeParams;
    public var ownerRef:PlayerRef;
    public var ownerELO:EloValue;

    public function toString() 
    {
        return 'ChallengeData(ID=$id, Owner=$ownerRef, $params)';
    }

    public function new()
    {
        
    }
}