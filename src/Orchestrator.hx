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

class CurrentData
{
    public var lastGameID:Int;
    public var loggedUsersByLogin:Map<String, User> = [];
    public var ongoingGamesByID:Map<Int, Game> = [];
    public var ongoingGamesByParticipantLogin:Map<String, Game> = [];
    public var activeOpenChallengesByOwnerLogin:Map<String, Array<Challenge>> = [];
    public var pendingDirectChallengesByOwnerLogin:Map<String, Array<Challenge>> = [];
    public var pendingDirectChallengesByReceiverLogin:Map<String, Array<Challenge>> = [];

    public function new()
    {
        lastGameID = Storage.computeLastGameID();
    }
}

class Orchestrator
{
    public static var data:CurrentData = new CurrentData(); //TODO: Distribute between services, make the data read-only outside of the corresponding service class

    public static function onPlayerDisconnected(user:User) //TODO: Short-time disconnection?
    {
        ChallengeManager.handleDisconnection(user);
        GameManager.handleDisconnection(user);
        if (user.login != null)
            data.loggedUsersByLogin.remove(user.login);
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
                onLogin(author, login, password);
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

    private static function onLogin(user:User, login:String, password:String) 
    {
        if (Auth.isValid(login, password))
        {
            user.signIn(login);
            data.loggedUsersByLogin.set(login, user);
            //TODO: Handle reconnection
            user.emit(LoginResult(Success([]))); //TODO: get and send incoming challenges
        }
        else 
            user.emit(LoginResult(Fail));
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