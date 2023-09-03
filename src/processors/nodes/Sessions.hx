package processors.nodes;

import net.Connection;
import utils.ds.DefaultArrayMap;
import processors.nodes.struct.UserSession;

class Sessions 
{
    private static var sessionByConnectionID:Map<String, UserSession> = [];
    private static var sessionBySessionID:Map<Int, UserSession> = [];
    private static var sessionByToken:Map<String, UserSession> = [];
    private static var sessionsByLogin:DefaultArrayMap<String, UserSession> = new DefaultArrayMap<String, UserSession>([]); 

    private static function logInfo(message:String) 
    {
        Logging.info("data/sessions", message);
    }

    public static function createNew(connection:Connection, ?login:String):UserSession
    {
        var session:UserSession = new UserSession();
        sessionBySessionID.set(id, session);
        sessionByToken.set(token, session);

        sessionByConnectionID.set(connection.id, session);
        session.connection = connection;

        if (login != null)
            setLogin(session, login);

        logInfo('Session created: id=${session.sessionID} | token=${session.token} | connection=${session.connection?.id} | login=${session.login}');

        return session;
    }

    public static function removeSession(session:UserSession)
    {
        if (session.connection != null)
            sessionByConnectionID.remove(session.connection.id);

        if (session.login != null)
            sessionsByLogin.pop(session.login, session);

        sessionBySessionID.remove(session.id);
        sessionByToken.remove(session.token);

        logInfo('Session ${session.sessionID} removed');
    }

    public static function setLogin(session:UserSession, login:Null<String>)
    {
        if (session.login != null)
            sessionsByLogin.pop(session.login, session);

        if (login != null)
            sessionsByLogin.push(login, session);

        session.login = login;

        logInfo('Login is set to ${session.login} for session ${session.sessionID}');
    }

    public static function unlinkConnection(session:UserSession) 
    {
        if (session.connection != null)
        {
            var oldConnectionID:String = session.connection.id;

            sessionByConnectionID.remove(oldConnectionID);
            session.connection = null;

            logInfo('Connection unlinked for session ${session.sessionID} (was $oldConnectionID)');
        }
    }

    public static function reconnectToSession(newConnection:Connection, session:UserSession) 
    {
        if (session.connection != null)
        {
            var oldConnection:Connection = session.connection;
            unlinkConnection(session);
            oldConnection.close();

            logInfo('Connection unlinked for session ${session.sessionID} due to reconnect (was ${oldConnection.id})');
        }
        
        sessionByConnectionID.set(newConnection.id, session);
        session.connection = newConnection;

        logInfo('A new connection (${newConnection.id}) was linked to session ${session.sessionID}');
    }

    public static function getByConnectionID(id:String):Null<UserSession>
    {
        return sessionsByConnectionID.get(id);
    }

    public static function getByToken(token:String):Null<UserSession>
    {
        return sessionByToken.get(token);
    }

    public static function getBySessionID(id:Int):Null<UserSession>
    {
        return sessionBySessionID.get(id);
    }

    public static function getByLogin(login:String):Array<UserSession>
    {
        return sessionsByLogin.get(login);
    }
}