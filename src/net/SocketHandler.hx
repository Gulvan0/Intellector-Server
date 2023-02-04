package net;

import haxe.io.BytesData;
import haxe.io.Bytes;
import lzstring.LZString;
import net.shared.ServerMessage;
import net.shared.utils.MathUtils;
import net.shared.ClientMessage;
import services.Shutdown;
import net.shared.utils.DateUtils;
import net.shared.utils.Build;
import services.LoginManager;
import haxe.Timer;
import haxe.CallStack;
import services.Auth;
import entities.UserSession;
import services.Logger;
import net.shared.ServerEvent;
import net.shared.ClientEvent;
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
    private var isNew:Bool = true;
    private var user:UserSession;
    private var silentConnectionDropTimer:Timer;
    private var ownHeartbeatTimer:Timer;
    private var clientHeartbeatTimeoutTimer:Timer;

    public function emit(msg:ServerMessage) 
    {
        var serialized:String = Serializer.run(msg);
        if (serialized.length < 1024)
            send(serialized);
        else
            send(Bytes.ofString(new LZString().compressToBase64(serialized)));
        Logger.logOutgoingMessage(msg, id, user);
    }

    private function onOpen()
    {
        Logger.serviceLog("SOCKET", '$id connected');
    }

    private function onClosed()
    {
        Logger.serviceLog("SOCKET", '$id closed');

        if (silentConnectionDropTimer != null)
            silentConnectionDropTimer.stop();
        silentConnectionDropTimer = null;

        if (ownHeartbeatTimer != null)
            ownHeartbeatTimer.stop();
        ownHeartbeatTimer = null;

        if (clientHeartbeatTimeoutTimer != null)
            clientHeartbeatTimeoutTimer.stop();
        clientHeartbeatTimeoutTimer = null;

        if (user != null)
            user.onDisconnected();
    }

    private function onError(e:Dynamic)
    {
        if (user != null)
            user.onDisconnected();
        handleError(ConnectionError(e));
    }

    private function handleError(error:NetworkingError)
    {
        Logger.serviceLog("SOCKET", '$id error');
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
        }
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

        try
        {
            var event:ClientEvent = EventTransformer.normalizeLogin(clientMessage.event);
            Logger.logIncomingMessage(clientMessage, id, user);
            
            if (isNew)
            {
                processFirstEvent(event);
                return;
            }

            switch event 
            {
                case Greet(greeting, clientBuild, minServerBuild):
                    Logger.logError('Unexpected greeting from connection $id');
                case KeepAliveBeat:
                    if (clientHeartbeatTimeoutTimer != null)
                        clientHeartbeatTimeoutTimer.stop();
                    clientHeartbeatTimeoutTimer = Timer.delay(onClientBeatTimeout, Config.keepAliveClientBeatTimeoutMs);
                case ResendRequest(from, to):
                    if (user == null)
                        Logger.logError('Unexpected event $event from connection $id with user == null');
                    else
                        user.resendMessages(from, to);
                case MissedEvents(map):
                    if (user == null)
                        Logger.logError('Unexpected event $event from connection $id with user == null');
                    else
                    {
                        var nextID:Int = user.lastProcessedClientEventID + 1;
                        while (map.exists(nextID))
                        {
                            Orchestrator.processEvent(map.get(nextID), user);
                            user.lastProcessedClientEventID = nextID;
                            nextID++;
                        }
                        user.lastReceivedClientEventID = MathUtils.maxInt(user.lastReceivedClientEventID, user.lastProcessedClientEventID);
                    }
                default:
                    if (clientMessage.id == -1)
                        Logger.logError('Event $event should have a message ID associated with it');
                    else if (user == null)
                        Logger.logError('Unexpected event $event from connection $id with user == null');
                    else if (clientMessage.id == user.lastProcessedClientEventID + 1)
                    {
                        Orchestrator.processEvent(event, user);
                        user.lastProcessedClientEventID = clientMessage.id;
                        user.lastReceivedClientEventID = MathUtils.maxInt(user.lastReceivedClientEventID, clientMessage.id);
                    }
                    else
                    {
                        user.lastReceivedClientEventID = MathUtils.maxInt(user.lastReceivedClientEventID, clientMessage.id);
                        if (user.lastReceivedClientEventID > user.lastProcessedClientEventID)
                            user.emit(ResendRequest(user.lastProcessedClientEventID + 1, user.lastReceivedClientEventID));
                    }
            }
        }
        catch (e)
        {
            handleError(ProcessingError(clientMessage.event, e, CallStack.exceptionStack(true)));
        }
    }

    private function processFirstEvent(event:ClientEvent) 
    {
        isNew = false;

        if (silentConnectionDropTimer != null)
            silentConnectionDropTimer.stop();
        silentConnectionDropTimer = null;

        switch event
        {
            case Greet(greeting, clientBuild, minServerBuild):
                Logger.serviceLog("SOCKET", 'Greeting received from $id');
                
                if (clientBuild < Config.minClientVer)
                {
                    if (user != null)
                        user.emit(GreetingResponse(OutdatedClient));
                    else
                        emit(new ServerMessage(-1, GreetingResponse(OutdatedClient)));
                    var actualDatetime:String = DateUtils.strDatetimeFromSecs(clientBuild);
                    var minDatetime:String = DateUtils.strDatetimeFromSecs(Config.minClientVer);
                    Logger.serviceLog("SOCKET", 'Refusing to connect $id: outdated client ($actualDatetime < $minDatetime)');
                    return;
                }

                if (Build.buildTime() < minServerBuild)
                {
                    if (user != null)
                        user.emit(GreetingResponse(OutdatedServer));
                    else
                        emit(new ServerMessage(-1, GreetingResponse(OutdatedServer)));
                    var actualDatetime:String = DateUtils.strDatetimeFromSecs(Build.buildTime());
                    var minDatetime:String = DateUtils.strDatetimeFromSecs(minServerBuild);
                    Logger.serviceLog("SOCKET", 'Refusing to connect $id: outdated server ($actualDatetime < $minDatetime)');
                    return;
                }

                switch greeting 
                {
                    case Simple:
                        this.user = Auth.createSession(this);
                        user.emit(GreetingResponse(ConnectedAsGuest(user.sessionID, Auth.getTokenBySessionID(user.sessionID), false, Shutdown.isStopping())));
                    case Login(login, password):
                        this.user = Auth.createSession(this);
                        LoginManager.login(user, login, password, true);
                    case Reconnect(token, lastProcessedMessageID):
                        var restoredUser:Null<UserSession> = Auth.getUserBySessionToken(token);
                        if (restoredUser != null)
                        {
                            this.user = restoredUser;
                            var missedEvents:Map<Int, ServerEvent> = user.onReconnected(this, lastProcessedMessageID);
                            user.emit(GreetingResponse(Reconnected(missedEvents)));
                        }
                        else
                        {
                            if (user != null)
                                user.emit(GreetingResponse(NotReconnected));
                            else
                                emit(new ServerMessage(-1, GreetingResponse(NotReconnected)));
                            Logger.serviceLog("SOCKET", '$id attempted to restore a session with a wrong token: $token');
                            return;
                        }
                }

                ownHeartbeatTimer = new Timer(Config.keepAliveOwnBeatIntervalMs);
                ownHeartbeatTimer.run = user.emit.bind(KeepAliveBeat);

                clientHeartbeatTimeoutTimer = Timer.delay(onClientBeatTimeout, Config.keepAliveClientBeatTimeoutMs);
            default:
                Logger.serviceLog("SOCKET", '$id sent an event without greeting, closing');
                close();
        }
    }

    private function onClientBeatTimeout() 
    {
        Logger.serviceLog("SOCKET", 'Stopped receiving heartbeat from $id, closing');
        close();
    }

    private function onNoGreetingAfterTimeout() 
    {
        Logger.serviceLog("SOCKET", '$id remained silent since the connection was estabilished, closing');
        close();
    }

    public function new(s:SocketImpl) 
    {
        super(s);

        var peer = s.peer();
        Logger.serviceLog("SOCKET", '$id created for ${peer.host.toString()}:${peer.port}');

        silentConnectionDropTimer = Timer.delay(onNoGreetingAfterTimeout, 1000 * 60);

        this.onopen = onOpen;
        this.onclose = onClosed;
        this.onerror = onError;
        this.onmessage = processMessage;
    }
}