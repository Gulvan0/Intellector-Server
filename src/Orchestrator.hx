package;

import database.endpoints.Challenge;
import net.shared.message.ClientRequest;
import net.shared.message.ClientEvent;
import services.util.ReconnectionResult;
import net.shared.dataobj.ChallengeData;
import services.util.LoginResult;
import entities.Connection;
import entities.events.ConnectionEvent;
import services.events.GenericServiceEvent;
import services.Service;
import database.Database;
import services.SubscriptionManager;
import services.SessionManager;
import net.shared.PieceColor;
import services.PageManager;
import services.ProfileManager;
import entities.Game;
import services.StudyManager;
import net.shared.dataobj.StudyInfo;
import net.EventTransformer;
import services.GameManager;
import services.ChallengeManager;
import entities.UserSession;

class Orchestrator
{
    private static var instance:Orchestrator;

    public final database:Database;

    public final sessionManager:SessionManager;
    public final subscriptionManager:SubscriptionManager;

    public final allServices:Array<Service>;

    public static function getInstance():Orchestrator
    {
        return instance;
    }

    public static function init() 
    {
        instance = new Orchestrator();
    }

    public function new()
    {
        //TODO: Fill
    }

    public function propagateServiceEvent(event:GenericServiceEvent)
    {
        for (service in allServices)
            service.handleServiceEvent(event);
    }

    private function onSimpleGreeting(connection:Connection)
    {
        var isShuttingDown:Bool = Shutdown.isStopping();
        var createdSessionData = sessionManager.createSession(connection);

        connection.emit(GreetingResponse(ConnectedAsGuest(createdSessionData.session.sessionID, createdSessionData.token, false, isShuttingDown)));
    }

    private function onLoginGreeting(connection:Connection, login:String, password:String)
    {
        var isShuttingDown:Bool = Shutdown.isStopping();
        var createdSessionData = sessionManager.createSession(connection);

        var loginResult:LoginResult = sessionManager.tryLogin(connection, login, password);

        switch loginResult 
        {
            case Logged:
                var incomingChallenges:Array<ChallengeData> = Challenge.getActiveIncoming(db, login);
                connection.emit(GreetingResponse(Logged(session.sessionID, createdSessionData.token, incomingChallenges, isShuttingDown)));
            default:
                connection.emit(GreetingResponse(ConnectedAsGuest(session.sessionID, createdSessionData.token, true, isShuttingDown)));
        }
    }

    private function onReconnectionGreeting(connection:Connection, token:String, lastProcessedServerEventID:Int, unansweredRequests:Array<Int>)
    {
        var reconnectionResult:ReconnectionResult = sessionManager.tryReconnect(connection, token, lastProcessedServerEventID, unansweredRequests);

        switch reconnectionResult 
        {
            case Reconnected(bundle):
                connection.emit(GreetingResponse(Reconnected(bundle)));
            case WrongToken:
                connection.emit(GreetingResponse(NotReconnected));
        }
    }

    public function handleConnectionEvent(connectionID:String, event:ConnectionEvent) 
    {
        switch event 
        {
            case GreetingReceived(greeting):
                var connection:Connection = Connection.getConnection(connectionID);
                switch greeting 
                {
                    case Simple:
                        onSimpleGreeting(connection);
                    case Login(login, password):
                        onLoginGreeting(connection, login, password);
                    case Reconnect(token, lastProcessedServerEventID, unansweredRequests):
                        onReconnectionGreeting(connection, token, lastProcessedServerEventID, unansweredRequests);
                }
            case EventReceived(id, event):
                processEvent(event);
            case RequestReceived(id, request):
                processRequest(event);
            case PresenceUpdated:
                sessionManager.onConnectionPresenceUpdated(connectionID);
            case Closed:
                sessionManager.onConnectionClosed(connectionID);
        }
    }

    public static function processEvent(event:ClientEvent, author:UserSession)
    {
        //TODO: Fill every case
        switch event 
        {
            case LogOut:
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

    public static function processRequest(id:Int, request:ClientRequest, author:UserSession)
    {
        //TODO: Fill every case
        switch request 
        {
            case Login(login, password):
                var loginResult:LoginResult = sessionManager.tryLogin(connection, login, password);

                switch loginResult 
                {
                    case Logged:
                        var incomingChallenges:Array<ChallengeData> = Challenge.getActiveIncoming(db, login);
                        author.respondToRequest(id, LoginResult(Success(incomingChallenges)));
                    default:
                        author.respondToRequest(id, LoginResult(Fail));
                }
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