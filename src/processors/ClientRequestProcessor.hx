package processors;

import processors.actions.Auth;
import net.shared.dataobj.SignInResult;
import processors.nodes.struct.UserSession;
import net.shared.message.ClientRequest;

class ClientRequestProcessor
{
    public static function process(author:UserSession, id:Int, request:ClientRequest) 
    {
        //TODO: Fill every case
        switch request 
        {
            case Login(login, password):
                var result:SignInResult = Auth.login(author, login, password);
                author.respondToRequest(id, LoginResult(result));
            case Register(login, password):
            case GetGamesByLogin(login, after, pageSize, filterByTimeControl):
            case GetStudiesByLogin(login, after, pageSize, filterByTags):
            case GetOngoingGamesByLogin(login):
            case GetMainMenuData:
            case GetOpenChallenges:
            case GetCurrentGames:
            case GetRecentGames:
            case GetGame(id):
            case GetStudy(id):
            case GetOpenChallenge(id):
            case GetMiniProfile(login):
            case GetPlayerProfile(login):
            case CreateChallenge(params):
            case CreateStudy(info):
            case Subscribe(subscription):
            case Unsubscribe(subscription):
        }
    }
}