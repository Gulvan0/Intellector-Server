package entities;

import net.shared.PieceType;

class CorrespondenceGame extends Game
{
    public function performPly(fromI:Int, fromJ:Int, toI:Int, toJ:Int, morphInto:Null<PieceType>)
    {
        //TODO: Fill
    }

    public function performTakeback(requestedBy:UserSession)
    {
        //TODO: Fill
    }

    public function sendMessage(author:UserSession, message:String)
    {
        //TODO: Fill
    }
    
    private function onRollback(moveCnt:Int)
    {
        //TODO: Fill
    }

    public function handleDisconnection(session:UserSession)
    {
        //Do nothing
    }

    public function handleReconnection(session:UserSession)
    {
        //Do nothing
    }

    public function new(id:Int) 
    {
        this.id = id;
    }    
}