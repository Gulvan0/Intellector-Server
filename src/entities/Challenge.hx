package entities;

import struct.ChallengeParams;

class Challenge 
{
    public var id:Int;
    public var params:ChallengeParams;
    public var ownerLogin:String;    

    public function new(id:Int, params:ChallengeParams, ownerLogin:String) 
    {
        this.id = id;
        this.params = params;
        this.ownerLogin = ownerLogin;
    }
}