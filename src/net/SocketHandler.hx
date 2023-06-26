package net;

import database.Database;
import database.TypedQueries;
import net.shared.dataobj.ChallengeData;
import sys.db.ResultSet;
import haxe.crypto.Md5;
import database.QueryShortcut;
import net.shared.message.ServerMessage;
import net.shared.dataobj.ReconnectionBundle;
import services.SessionManager;
import config.Config;
import net.shared.dataobj.GreetingResponseData;
import net.shared.dataobj.Greeting;
import net.shared.message.ClientMessage;
import utils.MovingCountdownTimer;
import haxe.io.BytesData;
import haxe.io.Bytes;
import lzstring.LZString;
import net.shared.utils.MathUtils;
import services.Shutdown;
import net.shared.utils.DateUtils;
import net.shared.utils.Build;
import services.LoginManager;
import haxe.Timer;
import haxe.CallStack;
import entities.UserSession;
import net.NetworkingError;
import haxe.Unserializer;
import haxe.Serializer;
import hx.ws.Buffer;
import hx.ws.Types.MessageType;
import hx.ws.SocketImpl;
import hx.ws.WebSocketHandler;
using Lambda;

class SocketHandler extends WebSocketHandler
{
    private var session:Null<UserSession>;

    private var silentConnectionDropTimer:Timer;
    private var afkTimer:MovingCountdownTimer;

    public var noActivity(default, null):Bool = false;

    public function emit(msg:ServerMessage) 
    {
        var serialized:String = Serializer.run(msg);
        if (serialized.length < 1024)
            send(serialized);
        else
            send(Bytes.ofString(new LZString().compressToBase64(serialized)));
        //Logger.logOutgoingMessage(msg, id, user);
    }

    private function onOpen()
    {
        //Logger.serviceLog("SOCKET", '$id connected');
    }

    private function onClosed()
    {
        //Logger.serviceLog("SOCKET", '$id closed');

        if (silentConnectionDropTimer != null)
            silentConnectionDropTimer.stop();
        silentConnectionDropTimer = null;

        if (afkTimer != null)
            afkTimer.stop();
        afkTimer = null;

        if (session != null)
            session.handleConnectionEvent(Closed);

        session = null;
    }

    private function onError(e:Dynamic)
    {
        if (session != null)
            session.handleConnectionEvent(Closed);
        handleError(ConnectionError(e));
    }

    private function handleError(error:NetworkingError)
    {
        //TODO
        /*Logger.serviceLog("SOCKET", '$id error');
        switch error 
        {
            case ConnectionError(error):
                Logger.logError('Connection error:\nUUID: $id\n$error', false);
            case BytesReceived(bytes):
                Logger.logError('Unexpected bytes:\nUUID: $id\n${bytes.toHex()}', false);
            case DeserializationError(message, exception):
                Logger.logError('Event deserialization failed:\nUUID: $id\nOriginal message: $message\nException:\n${exception.message}\nNative:\n${exception.native}\nPrevious:\n${exception.previous}\nStack:${exception.stack}');
            case ProcessingError(event, exception, stack):
                var eventStr:String = Logger.stringifyClientEvent(event);
                if (user != null)
                    user.emit(ServerError('Timestamp: ${Sys.time()}\nEvent: $eventStr\nException: ${exception.message} $stack'));
                else
                    emit(new ServerMessage(1, ServerError('Timestamp: ${Sys.time()}\nEvent: $eventStr\nException: ${exception.message} $stack')));
                Logger.logError('Error during event processing:\nUUID: $id\nEvent: $eventStr\nException:\n${exception.message}\nNative:\n${exception.native}\nPrevious:\n${exception.previous}\nStack:$stack');
        }*/
    }

    private function processMessage(message:MessageType)
    {
        switch message
        {
            case BytesMessage(content):
                handleError(BytesReceived(content.readAllAvailableBytes()));
            case StrMessage(content):
                processEvent(content);
        }
    }

    private function onGreeting(greeting:Greeting, clientBuild:Int, minServerBuild:Int)
    {
        if (silentConnectionDropTimer != null)
            silentConnectionDropTimer.stop();
        silentConnectionDropTimer = null;

        //TODO: Logger.serviceLog("SOCKET", 'Greeting received from $id');

        if (clientBuild < Config.config.minClientVer)
        {
            emit(GreetingResponse(OutdatedClient));

            var actualDatetime:String = DateUtils.strDatetimeFromSecs(clientBuild);
            var minDatetime:String = DateUtils.strDatetimeFromSecs(Config.minClientVer);
            //TODO: Logger.serviceLog("SOCKET", 'Refusing to connect $id: outdated client ($actualDatetime < $minDatetime)');

            return;
        }

        if (Build.buildTime() < minServerBuild)
        {
            emit(GreetingResponse(OutdatedServer));

            var actualDatetime:String = DateUtils.strDatetimeFromSecs(Build.buildTime());
            var minDatetime:String = DateUtils.strDatetimeFromSecs(minServerBuild);
            //TODO: Logger.serviceLog("SOCKET", 'Refusing to connect $id: outdated server ($actualDatetime < $minDatetime)');

            return;
        }

        var orchestrator:Orchestrator = Orchestrator.getInstance();
        var sessionManager:SessionManager = orchestrator.sessionManager;
        var db:Database = orchestrator.database;

        var isShuttingDown:Bool = Shutdown.isStopping();

        switch greeting 
        {
            case Simple:
                var createdSessionData = sessionManager.createSession(this);
                this.session = createdSessionData.session;
                emit(GreetingResponse(ConnectedAsGuest(session.sessionID, createdSessionData.token, false, isShuttingDown)));
            case Login(login, password):
                var createdSessionData = sessionManager.createSession(this);
                var queryResult:ResultSet = db.executeQuery(GetPasswordHash, ["login" => login])[0].set;
                var realPasswordHash:Null<String> = queryResult.length > 0? queryResult.getResult(0) : null;
                var receivedPasswordHash:String = Md5.encode(password);

                if (realPasswordHash == null)
                {
                    //TODO: Fill

                    //TODO: Logging
                }
                else if (realPasswordHash != receivedPasswordHash)
                {
                    //TODO: Fill

                    //TODO: Logging
                }
                else
                {
                    var createdSessionData = sessionManager.createSession(this);
                    this.session = createdSessionData.session;
                    this.session.login = login;
                    
                    emit(GreetingResponse(Logged(session.sessionID, createdSessionData.token, TypedQueries.getIncomingChallenges(db, login), isShuttingDown)));
                    //TODO: Logging
                }
            case Reconnect(token, lastProcessedServerEventID, unansweredRequests):
                var retrievedSession:Null<UserSession> = sessionManager.getByToken(token);
                if (retrievedSession != null)
                {
                    this.session = retrievedSession;
                    var bundle:ReconnectionBundle = this.session.onReconnected(this, lastProcessedServerEventID, unansweredRequests);
                    emit(GreetingResponse(Reconnected(bundle)));
                }
                else
                {
                    emit(GreetingResponse(NotReconnected));
                    //TODO: Logger.serviceLog("SOCKET", '$id attempted to restore a session with a wrong token: $token');
                }
        }

        afkTimer = new MovingCountdownTimer(onClientBeatTimeout, 1000 * 60 * 5); //TODO: Move delay to config
    }

    private function onBeat()
    {
        if (afkTimer != null)
            afkTimer.refresh();
        else
            afkTimer = new MovingCountdownTimer(onClientBeatTimeout, 1000 * 60 * 5); //TODO: Move delay to config
        
        var hadNoActivity:Bool = noActivity;

        noActivity = false;

        if (hadNoActivity && session != null)
            session.handleConnectionEvent(PresenceUpdated);
    }

    private function processEvent(message:String) 
    {
        var clientMessage:ClientMessage;

        try
        {
            clientMessage = Unserializer.run(message);
        }
        catch (e)
        {
            handleError(DeserializationError(message, e));
            return;
        }

        //TODO: Logger.logIncomingMessage(clientMessage, id, user);
        //TODO: Normalize login

        try
        {
            switch clientMessage 
            {
                case Greet(greeting, clientBuild, minServerBuild):
                    if (session != null)
                        trace("TODO");//TODO: Logger.logError('Unexpected greeting from connection $id');
                    else
                        onGreeting(greeting, clientBuild, minServerBuild);
                case HeartBeat:
                    onBeat();
                case Event(id, event):
                    if (session != null)
                        session.handleConnectionEvent(EventReceived(id, event));
                    else
                        trace("TODO");//TODO: Logger.logError('Unexpected event $event from connection $id with user == null');
                case Request(id, request):
                    if (session != null)
                        session.handleConnectionEvent(RequestReceived(id, request));
                    else
                        trace("TODO");//TODO: Logger.logError('Unexpected event $event from connection $id with user == null');
            }
        }
        catch (e)
        {
            handleError(ProcessingError(clientMessage.event, e, CallStack.exceptionStack(true)));
        }
    }

    private function onClientBeatTimeout() 
    {
        afkTimer = null;

        //TODO: Logger.serviceLog("SOCKET", 'Stopped receiving heartbeat from $id');

        noActivity = true;
        if (session != null)
            session.handleConnectionEvent(PresenceUpdated);
    }

    private function onNoGreetingAfterTimeout() 
    {
        //TODO: Logger.serviceLog("SOCKET", '$id remained silent since the connection was estabilished, closing');
        close();
    }

    public function new(s:SocketImpl) 
    {
        super(s);

        var peer = s.peer();
        //TODO: Logger.serviceLog("SOCKET", '$id created for ${peer.host.toString()}:${peer.port}');

        silentConnectionDropTimer = Timer.delay(onNoGreetingAfterTimeout, 1000 * 60);

        this.onopen = onOpen;
        this.onclose = onClosed;
        this.onerror = onError;
        this.onmessage = processMessage;
    }
}