package utils;

import net.shared.message.ClientMessage;
import net.shared.dataobj.Greeting;
import net.shared.message.ClientRequest;
import net.shared.message.ClientEvent;

class Normalizer 
{
    public static function normalizeMessage(message:ClientMessage):ClientMessage 
    {
        switch message 
        {
            case Greet(greeting, clientBuild, minServerBuild):
                return Greet(normalizeGreeting(greeting), clientBuild, minServerBuild);
            case HeartBeat:
                return HeartBeat;
            case Event(id, event):
                return Event(id, normalizeEvent(event));
            case Request(id, request):
                return Request(id, normalizeRequest(request));
        }
    }

    public static function normalizeEvent(event:ClientEvent):ClientEvent 
    {
        switch event 
        {
            case OverwriteStudy(overwrittenStudyID, info):
                if (info.ownerLogin != null)
                    info.ownerLogin.toLowerCase();
                return OverwriteStudy(overwrittenStudyID, info);
            case AddFriend(login):
                return AddFriend(login.toLowerCase());
            case RemoveFriend(login):
                return RemoveFriend(login.toLowerCase());
            default:
                return event;
        }    
    }

    public static function normalizeRequest(request:ClientRequest):ClientRequest
    {
        switch request 
        {
            case Login(login, password):
                return Login(login.toLowerCase(), password);
            case Register(login, password):
                return Register(login.toLowerCase(), password);
            case GetGamesByLogin(login, after, pageSize, filterByTimeControl):
                return GetGamesByLogin(login.toLowerCase(), after, pageSize, filterByTimeControl);
            case GetStudiesByLogin(login, after, pageSize, filterByTags):
                return GetStudiesByLogin(login.toLowerCase(), after, pageSize, filterByTags);
            case GetOngoingGamesByLogin(login):
                return GetOngoingGamesByLogin(login.toLowerCase());
            case GetMiniProfile(login):
                return GetMiniProfile(login.toLowerCase());
            case GetPlayerProfile(login):
                return GetPlayerProfile(login.toLowerCase());
            case CreateChallenge(params):
                switch params.type 
                {
                    case Direct(calleeRef):
                        params.type = Direct(calleeRef.normalized());
                    default:
                }
                return CreateChallenge(params);
            case CreateStudy(info):
                if (info.ownerLogin != null)
                    info.ownerLogin.toLowerCase();
                return CreateStudy(info);
            case Subscribe(PlayerProfileUpdates(ownerLogin)):
                return Subscribe(PlayerProfileUpdates(ownerLogin.toLowerCase()));
            case Subscribe(StartingGames(ref)):
                return Subscribe(StartingGames(ref.normalized()));
            case Unsubscribe(PlayerProfileUpdates(ownerLogin)):
                return Unsubscribe(PlayerProfileUpdates(ownerLogin.toLowerCase()));
            case Unsubscribe(StartingGames(ref)):
                return Unsubscribe(StartingGames(ref.normalized()));
            default:
                return request;
        }    
    }

    public static function normalizeGreeting(greeting:Greeting):Greeting
    {
        switch greeting 
        {
            case Login(login, password):
                return Login(login.toLowerCase(), password);
            default:
                return greeting;
        }
    }
}