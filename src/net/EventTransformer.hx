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

    public static function asGameAction(event:ClientEvent):Null<GameAction>
    {
        return switch event
        {
            case Move(_, fromI, toI, fromJ, toJ, morphInto): Move(fromI, toI, fromJ, toJ, morphInto);
            case RequestTimeoutCheck(_): RequestTimeoutCheck;
            case Message(_, text): Message(text);
            case Resign(_): Resign;
            case OfferDraw(_): OfferDraw;
            case CancelDraw(_): CancelDraw;
            case AcceptDraw(_): AcceptDraw;
            case DeclineDraw(_): DeclineDraw;
            case OfferTakeback(_): OfferTakeback;
            case CancelTakeback(_): CancelTakeback;
            case AcceptTakeback(_): AcceptTakeback;
            case DeclineTakeback(_): DeclineTakeback;
            case AddTime(_): AddTime;
            default: null;
        }
    }
}