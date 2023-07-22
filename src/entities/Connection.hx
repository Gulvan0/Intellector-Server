package entities;

import utils.Normalizer;
import database.Database;
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

class Connection extends WebSocketHandler
{
    private static inline final slug:String = "CONNECTION";

    private static var connectionMap:Map<String, Connection> = [];

    private var silentConnectionDropTimer:Timer;
    private var afkTimer:MovingCountdownTimer;

    public var noActivity(default, null):Bool = false;

    public static function getConnection(id:String):Connection
    {
        return connectionMap.get(id);
    }

    public function emit(msg:ServerMessage) 
    {
        var serialized:String = Serializer.run(msg);
        if (serialized.length < 1024)
            send(serialized);
        else
            send(Bytes.ofString(new LZString().compressToBase64(serialized)));

        Logging.serverMessage(id, msg);
    }

    private function onOpen()
    {
        Logging.info(slug, '$id connected');

        connectionMap.set(id, this);
    }

    private function onClosed()
    {
        Logging.info(slug, '$id closed');

        connectionMap.remove(id);

        if (silentConnectionDropTimer != null)
            silentConnectionDropTimer.stop();
        silentConnectionDropTimer = null;

        if (afkTimer != null)
            afkTimer.stop();
        afkTimer = null;

        Orchestrator.getInstance().handleConnectionEvent(this.id, Closed);
    }

    private function onError(e:Dynamic)
    {
        Orchestrator.getInstance().handleConnectionEvent(this.id, Closed);
        handleError(ConnectionError(e));
    }

    private function handleError(error:NetworkingError)
    {
        switch error 
        {
            case ConnectionError(error):
                Logging.error(slug, 'Connection error:\nUUID: $id\n$error', false);
            case BytesReceived(bytes):
                Logging.error(slug, 'Unexpected bytes:\nUUID: $id\n${bytes.toHex()}', false);
            case DeserializationError(message, exception):
                Logging.error(slug, 'Event deserialization failed:\nUUID: $id\nOriginal message: $message\nException:\n${exception.message}\nNative:\n${exception.native}\nPrevious:\n${exception.previous}\nStack:${exception.stack}');
            case ProcessingError(event, exception, stack):
                var eventStr:String = Logger.stringifyClientEvent(event);
                if (user != null)
                    user.emit(ServerError('Timestamp: ${Sys.time()}\nEvent: $eventStr\nException: ${exception.message} $stack'));
                else
                    emit(new ServerMessage(1, ServerError('Timestamp: ${Sys.time()}\nEvent: $eventStr\nException: ${exception.message} $stack')));
                Logging.error(slug, 'Error during event processing:\nUUID: $id\nEvent: $eventStr\nException:\n${exception.message}\nNative:\n${exception.native}\nPrevious:\n${exception.previous}\nStack:$stack');
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

    private function onGreeting(greeting:Greeting, clientBuild:Int, minServerBuild:Int)
    {
        if (silentConnectionDropTimer != null)
            silentConnectionDropTimer.stop();
        silentConnectionDropTimer = null;

        Logging.info(slug, 'Greeting received from $id');

        if (clientBuild < Config.config.minClientVer)
        {
            emit(GreetingResponse(OutdatedClient));

            var actualDatetime:String = DateUtils.strDatetimeFromSecs(clientBuild);
            var minDatetime:String = DateUtils.strDatetimeFromSecs(Config.minClientVer);
            Logging.info(slug, 'Refusing to connect $id: outdated client ($actualDatetime < $minDatetime)');

            return;
        }

        if (Build.buildTime() < minServerBuild)
        {
            emit(GreetingResponse(OutdatedServer));

            var actualDatetime:String = DateUtils.strDatetimeFromSecs(Build.buildTime());
            var minDatetime:String = DateUtils.strDatetimeFromSecs(minServerBuild);
            Logging.info(slug, 'Refusing to connect $id: outdated server ($actualDatetime < $minDatetime)');

            return;
        }

        Orchestrator.getInstance().handleConnectionEvent(this.id, GreetingReceived(greeting));

        afkTimer = new MovingCountdownTimer(onClientBeatTimeout, Config.config.clientHeartbeatTimeoutMs);
    }

    private function refreshAfkStatus()
    {
        if (afkTimer != null)
            afkTimer.refresh();
        else
            afkTimer = new MovingCountdownTimer(onClientBeatTimeout, Config.config.clientHeartbeatTimeoutMs);
        
        var hadNoActivity:Bool = noActivity;

        noActivity = false;

        if (hadNoActivity)
            Orchestrator.getInstance().handleConnectionEvent(this.id, PresenceUpdated);
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

        Logging.clientMessage(id, clientMessage);

        clientMessage = Normalizer.normalizeMessage(clientMessage);

        refreshAfkStatus();

        try
        {
            switch clientMessage 
            {
                case Greet(greeting, clientBuild, minServerBuild):
                    onGreeting(greeting, clientBuild, minServerBuild);
                case HeartBeat:
                    return;
                case Event(id, event):
                    Orchestrator.getInstance().handleConnectionEvent(this.id, EventReceived(id, event));
                case Request(id, request):
                    Orchestrator.getInstance().handleConnectionEvent(this.id, RequestReceived(id, request));
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

        Logging.info(slug, 'Stopped receiving heartbeat from $id');

        noActivity = true;
        Orchestrator.getInstance().handleConnectionEvent(this.id, PresenceUpdated);
    }

    private function onNoGreetingAfterTimeout() 
    {
        Logging.info(slug, '$id remained silent since the connection was estabilished, closing');
        close();
    }

    public function new(s:SocketImpl) 
    {
        super(s);

        var peer = s.peer();
        Logging.info(slug, '$id created for ${peer.host.toString()}:${peer.port}');

        silentConnectionDropTimer = Timer.delay(onNoGreetingAfterTimeout, 1000 * 60);

        this.onopen = onOpen;
        this.onclose = onClosed;
        this.onerror = onError;
        this.onmessage = processMessage;
    }
}