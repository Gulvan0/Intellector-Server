package services;

import services.util.ReconnectionResult;
import haxe.Timer;
import entities.util.SessionStatus;
import haxe.crypto.Md5;
import services.util.LoginResult;
import entities.Connection;
import services.events.GenericServiceEvent;
import utils.ds.DefaultArrayMap;
import net.shared.utils.PlayerRef;
import net.shared.utils.MathUtils;
import entities.UserSession;

class SessionManager extends Service
{
    private var lastSessionID:Int = 0;

    private var sessionByConnectionID:Map<String, UserSession> = [];
    private var sessionBySessionID:Map<Int, UserSession> = [];
    private var sessionByToken:Map<String, UserSession> = [];
    private var sessionsByLogin:DefaultArrayMap<String, UserSession> = new DefaultArrayMap<String, UserSession>([]);

    private var sessionDestructionTimerBySessionID:Map<Int, Timer> = [];

    public function getServiceSlug():Null<String>
    {
        return "session";
    }

    public function createSession(connection:Connection):{session:UserSession, token:String}
    {
        var id:Int = ++lastSessionID;
        var token:String = generateSessionToken();
        var session:UserSession = new UserSession(connection, id, token, handleSessionEvent);

        sessionByConnectionID.set(connection.id, session);
        sessionBySessionID.set(id, session);
        sessionByToken.set(token, session);

        logInfo('Session $id created for connection ${connection.id} with token $token');

        orchestrator.propagateServiceEvent(Session(NewSession(session)));

        return user;
    }

    public function tryLogin(connection:Connection, login:String, password:String):LoginResult
    {
        var session:Null<UserSession> = getByConnectionID(connection.id);
        var passwordHash:Null<String> = Player.getPasswordHash(orchestrator.database, login);

        if (session == null)
        {
            logError('tryLogin() is called, but no session is assigned to the connection with id ${connection.id}');
            return OtherError;
        }
        
        logInfo('$session attempts logging in as $login');

        if (passwordHash == null)
        {
            logInfo('Failed to log $user in as $login: user does not exist');
            return PlayerNotFound;
        }
        else if (passwordHash != Md5.encode(password))
        {
            logInfo('Failed to log $user in as $login: invalid password');
            return WrongPassword;
        }
        else
        {
            logInfo('Logging $user as $login...');

            sessionsByLogin.push(login, session);
            session.login = login;
            
            logInfo('Logged $user in; propagating the login update event...');

            orchestrator.propagateServiceEvent(Session(SessionLoginUpdated(session)));

            var otherSessionsAggregatedStatus:SessionStatus = getAggregatedPlayerStatus(session.login, session.sessionID);
            var sessionIsDecisive:Bool = otherSessionsAggregatedStatus != Active;

            if (sessionIsDecisive)
            {
                logInfo('$login\'s status has changed to Active, propagating this event as well...');

                orchestrator.propagateServiceEvent(Session(PlayerStatusUpdated(session.login, Active)));
            }
            else
                logInfo('$login\'s status has already been Active, the corresponding event will not be emitted');

            return Logged;
        }
    }

    public function tryReconnect(connection:Connection, token:String, lastProcessedServerEventID:Int, unansweredRequests:Array<Int>):ReconnectionResult
    {
        var retrievedSession:Null<UserSession> = getByToken(token);

        if (retrievedSession != null)
        {
            logInfo('${connection.id} reconnected to session ${retrievedSession.sessionID}');

            var previousStatus:SessionStatus = retrievedSession.getSessionStatus();

            if (retrievedSession.connection != null)
            {
                sessionByConnectionID.remove(retrievedSession.connection.id);
                retrievedSession.connection.close();
            }

            sessionByConnectionID.set(connection.id, retrievedSession);

            var bundle:ReconnectionBundle = retrievedSession.onReconnected(this, lastProcessedServerEventID, unansweredRequests);

            if (previousStatus != Active)
            {
                logInfo('Session ${retrievedSession.sessionID}\'s status was $previousStatus, propagating status update event');

                orchestrator.propagateServiceEvent(Session(SessionStatusUpdated(retrievedSession)));
            }
            else
                logInfo('Session ${retrievedSession.sessionID}\'s status has already been Active, the corresponding event will not be emitted');

            if (retrievedSession.login != null)
            {
                var otherSessionsAggregatedStatus:SessionStatus = getAggregatedPlayerStatus(retrievedSession.login, retrievedSession.sessionID);
                var sessionIsDecisive:Bool = otherSessionsAggregatedStatus != Active;
    
                if (sessionIsDecisive)
                {
                    logInfo('$login\'s status has changed to Active, propagating this event as well...');
    
                    orchestrator.propagateServiceEvent(Session(PlayerStatusUpdated(retrievedSession.login, Active)));
                }
                else
                    logInfo('$login\'s status has already been Active, the corresponding event will not be emitted');
            }

            return Reconnected(bundle);
        }
        else
        {
            logInfo('${connection.id} attempted to restore a session with a wrong token: $token');

            return WrongToken;
        }
    }

    public function logout(connection:Connection)
    {
        var session:Null<UserSession> = getByConnectionID(connection.id);
        
        logInfo('$session attempts logging out');

        if (session.login == null)
        {
            logInfo('$session was not logged in the first place');
            return;
        }

        sessionsByLogin.pop(session.login, session);
        session.login = null;

        logInfo('Logged $session out, propagating the corresponding event...');

        orchestrator.propagateServiceEvent(Session(SessionLoginUpdated(session)));
    }

    public function onConnectionPresenceUpdated(id:String)
    {
        var session:Null<UserSession> = getByConnectionID(connection.id);

        if (session == null)
        {
            logInfo('Connection ${connection.id} is not associated with a session, skipping presence event handling');
            return;
        }

        orchestrator.propagateServiceEvent(Session(SessionStatusUpdated(session)));

        if (session.login != null)
        {
            var otherSessionsAggregatedStatus:SessionStatus = getAggregatedPlayerStatus(session.login, session.sessionID);
            var sessionIsDecisive:Bool = otherSessionsAggregatedStatus != Active;

            if (sessionIsDecisive)
            {
                var overallStatus:SessionStatus = session.connection.noActivity? Away : Active;

                logInfo('Sessions of player ${session.login} other than ${session.sessionID} are inactive, therefore, this update will affect player status (becomes $overallStatus)');

                orchestrator.propagateServiceEvent(Session(PlayerStatusUpdated(session.login, overallStatus)));
            }
        }
    }

    public function onConnectionClosed(id:String)
    {
        var session:Null<UserSession> = getByConnectionID(connection.id);

        if (session == null)
        {
            logInfo('Connection ${connection.id} is not associated with a session, skipping closure event handling');
            return;
        }

        sessionByConnectionID.remove(id);

        if (!sessionDestructionTimerBySessionID.exists(session.sessionID))
        {
            var destructionCallback:Void->Void = onSessionTimeout.bind(session.sessionID);
            var oneDayMs:Int = 1000 * 60 * 60 * 24;
            var destructionTimer:Timer = Timer.delay(destructionCallback, oneDayMs);

            sessionDestructionTimerBySessionID.set(session.sessionID, destructionTimer);

            logInfo('Destruction timer created for session ${session.sessionID}');
        }
        else
            logInfo('Connection closure event was received, however, destruction timer for session ${session.sessionID} already exists');

        orchestrator.propagateServiceEvent(Session(SessionStatusUpdated(session)));

        if (session.login != null)
        {
            var otherSessionsAggregatedStatus:SessionStatus = getAggregatedPlayerStatus(session.login, session.sessionID);

            if (otherSessionsAggregatedStatus == NotConnected)
            {
                logInfo('All sessions of player ${session.login} are not connected, propagating player status update (becomes NotConnected)');

                orchestrator.propagateServiceEvent(Session(PlayerStatusUpdated(session.login, NotConnected)));
            }
        }
    }

    private function onSessionTimeout(sessionID:Int)
    {
        logInfo('Session ${sessionID} timed out. Destroying...');

        var session:UserSession = sessionBySessionID.get(sessionID);

        if (session == null)
        {
            logError('Session $sessionID timed out and was going to be destroyed, but was not found in sessionBySessionID map');
            return;
        }
        
        orchestrator.propagateServiceEvent(Session(SessionToBeDestroyed(session)));

        sessionBySessionID.remove(sessionID);
        sessionByToken.remove(session.token);
        if (session.login != null)
            sessionsByLogin.pop(session.login, session);
    }

    public function getAggregatedPlayerStatus(login:String, ?excludedSessionID:Int):SessionStatus
    {
        var hasConnectedSession:Bool = false;

        for (session in sessionsByLogin.get(login))
            if (excludedSessionID == null || session.sessionID != excludedSessionID)
                switch session.getSessionStatus() 
                {
                    case Active:
                        return Active;
                    case Away:
                        hasConnectedSession = true;
                    default:
                }

        if (hasConnectedSession)
            return Away;
        else
            return NotConnected;
    }

    private function generateSessionToken():String
    {
        var token:String = "_";
        for (i in 0...25)
            token += String.fromCharCode(MathUtils.randomInt(33, 126));
        
        return sessionByToken.exists(token)? generateSessionToken() : token;
    }

    public function getByConnectionID(connectionID:Int):Null<UserSession>
    {
        return sessionByConnectionID.get(connectionID);
    }

    public function getByLogin(login:String):Array<UserSession>
    {
        return sessionsByLogin.get(login);
    }

    public function getBySessionID(sessionID:Int):Null<UserSession>
    {
        return sessionBySessionID.get(sessionID);
    }

    public function getByToken(token:String):Null<UserSession> 
    {
        return sessionByToken.get(token);
    }

    public function handleServiceEvent(genericEvent:GenericServiceEvent)
    {
        switch genericEvent 
        {
            case Session(event):
                return; //Disregard own event
        }
    }

    private function guestRefBySessionID(sessionID:Int) 
    {
        return '_$sessionID';
    }

    private function isGuestRef(ref:PlayerRef) 
    {
        return ref.concretize().match(Guest(_));    
    }

    public function new(orchestrator:Orchestrator) 
    {
        super(orchestrator);    
    }
}