package net;

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

    public function emit(event:ServerEvent) 
    {
        Logger.logOutgoingEvent(event, id, user);
        send(Serializer.run(event));
    }

    private function onOpen()
    {
        Logger.serviceLog("SOCKET", '$id connected');
    }

    private function onClosed()
    {
        Logger.serviceLog("SOCKET", '$id closed');
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
                emit(ServerError('Timestamp: ${Sys.time()}\nEvent: $event\nException: ${exception.message} $stack'));
                Logger.logError('Error during event processing:\nUUID: $id\nEvent: $event\nException:\n${exception.message}\nNative:\n${exception.native}\nPrevious:\n${exception.previous}\nStack:$stack');
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
        var event:ClientEvent = null;

        try
        {
            event = Unserializer.run(message);
        }
        catch (e)
        {
            handleError(DeserializationError(message, e));
            return;
        }

        try
        {
            event = EventTransformer.normalizeLogin(event);
            Logger.logIncomingEvent(event, id, user);
            
            if (isNew)
                processFirstEvent(event);
            else
                Orchestrator.processEvent(event, user);
        }
        catch (e)
        {
            handleError(ProcessingError(event, e, CallStack.exceptionStack(true)));
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
                    emit(GreetingResponse(OutdatedClient));
                    var actualDatetime:String = DateUtils.strDatetimeFromSecs(clientBuild);
                    var minDatetime:String = DateUtils.strDatetimeFromSecs(Config.minClientVer);
                    Logger.serviceLog("SOCKET", 'Refusing to connect $id: outdated client ($actualDatetime < $minDatetime)');
                    return;
                }

                if (Build.buildTime() < minServerBuild)
                {
                    emit(GreetingResponse(OutdatedServer));
                    var actualDatetime:String = DateUtils.strDatetimeFromSecs(Build.buildTime());
                    var minDatetime:String = DateUtils.strDatetimeFromSecs(minServerBuild);
                    Logger.serviceLog("SOCKET", 'Refusing to connect $id: outdated server ($actualDatetime < $minDatetime)');
                    return;
                }

                switch greeting 
                {
                    case Simple:
                        this.user = Auth.createSession(this);
                        emit(GreetingResponse(ConnectedAsGuest(user.reconnectionToken, false, Shutdown.isStopping())));
                    case Login(login, password):
                        this.user = Auth.createSession(this);
                        LoginManager.login(user, login, password, true);
                    case Reconnect(token):
                        var restoredUser:Null<UserSession> = Auth.getUserBySessionToken(token);
                        if (restoredUser != null)
                        {
                            this.user = restoredUser;
                            var missedEvents = user.onReconnected(this);
                            emit(GreetingResponse(Reconnected(missedEvents)));
                        }
                        else
                        {
                            emit(GreetingResponse(NotReconnected));
                            Logger.serviceLog("SOCKET", '$id attempted to restore a session with a wrong token: $token');
                        }
                }
            default:
                Logger.serviceLog("SOCKET", '$id sent an event without greeting, closing');
                close();
        }
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