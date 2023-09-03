package processors;

import processors.actions.Auth;
import processors.nodes.struct.UserSession;
import net.shared.message.ClientEvent;

class ClientEventProcessor
{
    public static function process(author:UserSession, event:ClientEvent) 
    {
        //TODO: Fill every case
        switch event 
        {
            case LogOut:
                Auth.logout(author);
            case CancelChallenge(challengeID):
            case AcceptChallenge(challengeID):
            case DeclineDirectChallenge(challengeID):
            case Move(ply):
            case Message(text):
            case SimpleRematch:
            case Resign:
            case PerformOfferAction(kind, action):
            case AddTime:
            case BotGameRollback(plysReverted, updatedTimestamp):
            case BotMessage(text):
            case OverwriteStudy(overwrittenStudyID, info):
            case DeleteStudy(id):
            case AddFriend(login):
            case RemoveFriend(login):
        }
    }
}