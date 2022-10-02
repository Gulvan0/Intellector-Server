package net;

import net.shared.ClientEvent;

class EventTransformer
{
    public static function normalizeLogin(event:ClientEvent):ClientEvent
    {
        return switch event 
        {
            case Login(login, password):
                Login(login.toLowerCase(), password);
            case Register(login, password):
                Register(login.toLowerCase(), password);
            case CreateChallenge(serializedParams):
            case AcceptOpenChallenge(challengeID, guestLogin, guestPassword):
                AcceptOpenChallenge(challengeID, guestLogin.toLowerCase(), password);
            case FollowPlayer(login):
                FollowPlayer(login.toLowerCase());
            case GetMiniProfile(login):
                GetMiniProfile(login.toLowerCase());
            case GetPlayerProfile(login):
                GetPlayerProfile(login.toLowerCase());
            case AddFriend(login):
                AddFriend(login.toLowerCase());
            case RemoveFriend(login):
                RemoveFriend(login.toLowerCase());
            case GetGamesByLogin(login, after, pageSize, filterByTimeControl):
                GetGamesByLogin(login.toLowerCase(), after, pageSize, filterByTimeControl);
            case GetStudiesByLogin(login, after, pageSize, filterByTags):
                GetStudiesByLogin(login.toLowerCase(), after, pageSize, filterByTags);
            case GetOngoingGamesByLogin(login):
                GetOngoingGamesByLogin(login.toLowerCase());
            default: 
                event;
        }
    }
}