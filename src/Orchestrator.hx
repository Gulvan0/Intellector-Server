package;

import struct.ChallengeParams;
import services.ChallengeManager;
import services.LoginManager;
import entities.util.UserState;
import services.Logger;
import entities.UserSession;
import net.shared.ClientEvent;

class Orchestrator
{
    public static function processEvent(event:ClientEvent, author:UserSession)
    {
        var authorID:String = author.connection.id;
        var authorState:UserState = author.getState();

        Logger.logIncomingEvent(event, authorID, author.login);

        if (!isEventRelevant(event, authorState))
        {
            Logger.logError('Skipping irrelevant event ${event.getName()} for author $authorID (state = ${authorState.getName()})');
            return;
        }
        
        author.storedData.onMessageReceived();

        switch event 
        {
            case Login(login, password):
                LoginManager.login(author, login, password);
            case Register(login, password):
                LoginManager.register(author, login, password);
            case RestoreSession(token):
                Logger.logError('Error: trying to process RestoreSession event inside the Orchestrator method. Token: $token');
            case LogOut:
                LoginManager.logout(author);

            case CreateChallenge(serializedParams):
                ChallengeManager.create(author, ChallengeParams.deserialize(serializedParams));
            case CancelChallenge(challengeID):
                ChallengeManager.cancel(author, challengeID);
            case AcceptChallenge(challengeID):
                ChallengeManager.accept(author, challengeID);
            case DeclineDirectChallenge(challengeID):
                ChallengeManager.decline(author, challengeID);
            case GetOpenChallenge(id):
                ChallengeManager.getOpenChallenge(author, id);

            case FollowPlayer(login):
            case StopFollowing:
            case StopSpectating:

            case Move(fromI, toI, fromJ, toJ, morphInto):
            case RequestTimeoutCheck:
            case Message(text):
            case Resign:
            case OfferDraw:
            case CancelDraw:
            case AcceptDraw:
            case DeclineDraw:
            case OfferTakeback:
            case CancelTakeback:
            case AcceptTakeback:
            case DeclineTakeback:
            case AddTime:
            case SimpleRematch:

            case CreateStudy(info):
            case OverwriteStudy(overwrittenStudyID, info):
            case DeleteStudy(id):

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
            case RestoreSession(token): [];
            case LogOut: [Browsing, InGame];
            case CreateChallenge(serializedParams): [Browsing];
            case CancelChallenge(challengeID): [Browsing]; 
            case AcceptChallenge(challengeID): [NotLogged, Browsing];
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
            case SimpleRematch: [Browsing];
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