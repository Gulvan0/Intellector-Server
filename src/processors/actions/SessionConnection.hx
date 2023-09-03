package processors.actions;

import processors.nodes.Subscriptions;
import net.shared.dataobj.ReconnectionBundle;
import database.endpoints.Challenge;
import net.shared.dataobj.ChallengeData;
import processors.actions.Auth;
import processors.actions.returned.CredentialsCheckResult;
import net.shared.dataobj.GreetingResponseData;
import processors.nodes.struct.UserSession;
import processors.nodes.Sessions;
import net.Connection;

class SessionConnection
{
    private static function logInfo(message:String) 
    {
        Logging.info("actions/sessionConnection", message);
    }

    private static function logError(message:String, ?notifyAdmin:Bool = true) 
    {
        Logging.error("actions/sessionConnection", message, notifyAdmin);
    }

    public static function processSimpleGreeting(connection:Connection) 
    {
        var existingSession:Null<UserSession> = Sessions.getByConnectionID(connection.id);

        if (existingSession != null)
        {
            logError('Simple greeting received from connection ${connection.id}, but it already has a session associated (id=${existingSession.sessionID})', false);
            return;
        }

        var newSession:UserSession = Sessions.createNew(connection);
        var greetingResponse:GreetingResponseData = ConnectedAsGuest(newSession.sessionID, newSession.token, false, Server.isShuttingDown());

        connection.emit(GreetingResponse(greetingResponse));
    }

    public static function processLoginGreeting(connection:Connection, login:String, password:String) 
    {
        logInfo('${connection.id} attempts logging in as $login');

        var existingSession:Null<UserSession> = Sessions.getByConnectionID(connection.id);

        if (existingSession != null)
        {
            logError('Login (as $login) greeting received from connection ${connection.id}, but it already has a session associated (id=${existingSession.sessionID})', false);
            return;
        }

        var checkResult:CredentialsCheckResult = Auth.checkCredentials(login, password);

        logInfo('Credentials check result for ${connection.id} returned $checkResult');

        if (checkResult != Valid)
        {
            var newSession:UserSession = Sessions.createNew(connection);
            var greetingResponse:GreetingResponseData = ConnectedAsGuest(newSession.sessionID, newSession.token, true, Server.isShuttingDown());

            connection.emit(GreetingResponse(greetingResponse));
            return;
        }

        var newSession:UserSession = Sessions.createNew(connection, login);
        var incomingChallenges:Array<ChallengeData> = Challenge.getActiveIncoming(login);
        var greetingResponse:GreetingResponseData = Logged(newSession.sessionID, newSession.token, incomingChallenges, Server.isShuttingDown());

        //TODO: Broadcast: player status update; new session for login???
        
        connection.emit(GreetingResponse(greetingResponse));
    }

    public static function processReconnectGreeting(connection:Connection, token:String, lastProcessedServerEventID:Int, unansweredRequests:Array<Int>) 
    {
        var retrievedSession:Null<UserSession> = Sessions.getByToken(token);

        if (retrievedSession == null)
        {
            logInfo('${connection.id} attempted to restore a session with a wrong token: $token');
            connection.emit(GreetingResponse(NotReconnected));
            return;
        }

        Sessions.reconnectToSession(connection, retrievedSession);
        
        logInfo('${connection.id} reconnected to session ${retrievedSession.sessionID}');

        //TODO: Broadcast: player status update; session status update???

        var bundle:ReconnectionBundle = retrievedSession.constructReconnectionBundle(lastProcessedServerEventID, unansweredRequests);
        connection.emit(GreetingResponse(Reconnected(bundle)));
    }

    public static function onPresenceUpdated(connection:Connection)
    {
        var session:Null<UserSession> = Sessions.getByConnectionID(connection.id);

        if (session == null)
        {
            logInfo('${connection.id} is not associated with a session, skipping presence event handling');
            return;
        }

        //TODO: Broadcast: player status update; session status update???
    }

    public static function onClosed(connection:Connection)
    {
        var session:Null<UserSession> = getByConnectionID(connection.id);

        if (session == null)
        {
            logInfo('Connection ${connection.id} is not associated with a session, skipping closure event handling');
            return;
        }

        Sessions.removeSession(session);
        Subscriptions.removeSessionFromAllSubscriptions(session);
        //TODO: More?

        //TODO: Broadcast: player status update; session status update???
    }

    //TODO: Session destruction by timeout, status update notifications (player/session)
}