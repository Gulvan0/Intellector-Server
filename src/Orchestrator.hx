package;

import net.shared.SignInResult;
import services.Auth;
import services.GameManager;
import services.ChallengeManager;
import services.Storage;
import entities.Challenge;
import entities.Game;
import entities.util.UserState;
import services.Logger;
import entities.User;
import net.shared.ClientEvent;

class Orchestrator
{
    public static function onPlayerDisconnected(user:User) //TODO: Short-time disconnection?
    {
        ChallengeManager.handleDisconnection(user);
        GameManager.handleDisconnection(user);
        //TODO: other manages should handle that too
        
        //TODO: Stop spectating or following
    }

    public static function processEvent(event:ClientEvent, author:User) 
    {
        var authorID:String = author.connection.id;
        var authorState:UserState = author.getState();

        Logger.logIncomingEvent(event, authorID, author.login);

        if (!isEventRelevant(event, authorState))
        {
            Logger.logError('Skipping irrelevant event ${event.getName()} for author $authorID (state = ${authorState.getName()})');
            return;
        }

        switch event 
        {
            case Login(login, password):
                //LoginManager.onLogin(author, login, password);
            case Register(login, password):
            case LogOut:
            case CreateChallenge(serializedParams):
            case CancelChallenge(challengeID):
            case AcceptOpenChallenge(challengeID, guestLogin, guestPassword):
            case AcceptDirectChallenge(challengeID):
            case DeclineDirectChallenge(challengeID):
            case Move(fromI, toI, fromJ, toJ, morphInto):
            case RequestTimeoutCheck:
            case Message(text):
            case GetOpenChallenge(id):
            case FollowPlayer(login):
            case StopSpectating:
            case StopFollowing:
            case Resign:
            case OfferDraw:
            case CancelDraw:
            case AcceptDraw:
            case DeclineDraw:
            case OfferTakeback:
            case CancelTakeback:
            case AcceptTakeback:
            case DeclineTakeback:
            case CreateStudy(info):
            case OverwriteStudy(overwrittenStudyID, info):
            case DeleteStudy(id):
            case AddTime:
            case GetGame(id):
            case GetStudy(id):
            case GetMiniProfile(login):
            case GetPlayerProfile(login):
            case AddFriend(login):
            case RemoveFriend(login):
            case GetGamesByLogin(login, after, pageSize, filterByTimeControl):
            case GetStudiesByLogin(login, after, pageSize, filterByTags):
            case GetOngoingGamesByLogin(login):
            case GetOpenChallenges:
            case GetCurrentGames:
        }
    }

    private static function isEventRelevant(event:ClientEvent, state:UserState) 
    {
        var possibleStates:Array<UserState> = switch event 
        {
            case Login(login, password): [NotLogged];
            case Register(login, password): [NotLogged];
            case LogOut: [Browsing, InGame];
            case CreateChallenge(serializedParams): [Browsing];
            case CancelChallenge(challengeID): [Browsing]; 
            case AcceptOpenChallenge(challengeID, guestLogin, guestPassword) if (guestLogin != null): [NotLogged];
            case AcceptOpenChallenge(challengeID, guestLogin, guestPassword): [Browsing];
            case AcceptDirectChallenge(challengeID): [Browsing];
            case DeclineDirectChallenge(challengeID): [Browsing];
            case Move(fromI, toI, fromJ, toJ, morphInto): [InGame];
            case RequestTimeoutCheck: [InGame];
            case Message(text): [InGame];
            case GetOpenChallenge(id): [NotLogged, Browsing];
            case FollowPlayer(login): [NotLogged, Browsing];
            case StopSpectating: [NotLogged, Browsing];
            case StopFollowing: [NotLogged, Browsing];
            case Resign: [InGame];
            case OfferDraw: [InGame];
            case CancelDraw: [InGame];
            case AcceptDraw: [InGame];
            case DeclineDraw: [InGame];
            case OfferTakeback: [InGame];
            case CancelTakeback: [InGame];
            case AcceptTakeback: [InGame];
            case DeclineTakeback: [InGame];
            case AddTime: [InGame];
            case CreateStudy(info): [Browsing];
            case OverwriteStudy(overwrittenStudyID, info): [Browsing];
            case DeleteStudy(id): [Browsing];
            case GetGame(id): [NotLogged, Browsing];
            case GetStudy(id): [NotLogged, Browsing];
            case GetMiniProfile(login): [NotLogged, Browsing];
            case GetPlayerProfile(login): [NotLogged, Browsing];
            case AddFriend(login): [Browsing];
            case RemoveFriend(login): [Browsing];
            case GetGamesByLogin(login, after, pageSize, filterByTimeControl): [NotLogged, Browsing];
            case GetStudiesByLogin(login, after, pageSize, filterByTags): [NotLogged, Browsing];
            case GetOngoingGamesByLogin(login): [NotLogged, Browsing];
            case GetOpenChallenges: [NotLogged, Browsing];
            case GetCurrentGames: [NotLogged, Browsing];
        }
        return possibleStates.contains(state);
    }
}