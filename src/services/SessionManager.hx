package services;

import net.shared.utils.PlayerRef;
import net.shared.utils.MathUtils;
import entities.events.SessionEvent;
import net.SocketHandler;
import entities.UserSession;

class SessionManager extends Service
{
    private var lastSessionID:Int = 0;

    private var sessionByRef:Map<PlayerRef, UserSession> = [];
    private var sessionByToken:Map<String, UserSession> = [];

    public function getServiceSlug():Null<String>
    {
        return "session";
    }

    public function createSession(connection:SocketHandler):{session:UserSession, token:String}
    {
        var id:Int = ++lastSessionID;
        var token:String = generateSessionToken();
        var session:UserSession = new UserSession(connection, id, handleSessionEvent);

        sessionByRef.set(guestRefBySessionID(id), session);
        sessionByToken.set(token, session);

        //TODO: Logger.serviceLog(serviceName, 'Session created for $user: $token');
        return user;
    }

    private function generateSessionToken():String
    {
        var token:String = "_";
        for (i in 0...25)
            token += String.fromCharCode(MathUtils.randomInt(33, 126));
        
        return sessionByToken.exists(token)? generateSessionToken() : token;
    }

    public function getByRef(ref:PlayerRef, admitLoggedByFormerGuestRef:Bool):Null<UserSession>
    {
        var session:Null<UserSession> = sessionByRef.get(ref);

        if (session == null)
            return null;
        else if (admitLoggedByFormerGuestRef || session.login == null || !isGuestRef(ref))
            return session;
        else
            return null;
    }

    public function getByToken(token:String):Null<UserSession> 
    {
        return sessionByToken.get(token);
    }

    public function onSessionDestroyed(user:UserSession) 
    {
        sessionByRef.remove(user.login);
        sessionByRef.remove(guestRefBySessionID(user.sessionID));
        sessionByToken.remove(user.token);
    }

    private function handleSessionEvent(session:UserSession, event:SessionEvent)
    {
        switch event 
        {
            case LoginUpdated:
                if (user.login != null)
                    sessionByRef.set(user.login, user);
                else
                    sessionByRef.remove(formerLogin);
            case StatusChanged:
                //TODO
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