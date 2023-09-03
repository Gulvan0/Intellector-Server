package net;

import processors.ClientRequestProcessor;
import processors.ClientEventProcessor;
import processors.nodes.Sessions;
import processors.nodes.struct.UserSession;
import processors.ConnectionEventProcessor;
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
import net.shared.utils.DateUtils;
import net.shared.utils.Build;
import haxe.Timer;
import haxe.CallStack;
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
    private static var connectionMap:Map<String, Connection> = [];

    private var silentConnectionDropTimer:Timer;
    private var afkTimer:MovingCountdownTimer;
    private var connectionHangupTimer:Timer;

    public var noActivity(default, null):Bool = false;

    private static function logInfo(message:String) 
    {
        Logging.info("net/connection", message);
    }

    private static function logError(message:String, ?notifyAdmin:Bool = true) 
    {
        Logging.error("net/connection", message, notifyAdmin);
    }

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
        logInfo('$id connected');

        connectionMap.set(id, this);
    }

    private function onClosed()
    {
        logInfo('$id closed');

        connectionMap.remove(id);

        if (connectionHangupTimer != null)
            connectionHangupTimer.stop();
        connectionHangupTimer = null;

        if (silentConnectionDropTimer != null)
            silentConnectionDropTimer.stop();
        silentConnectionDropTimer = null;

        if (afkTimer != null)
            afkTimer.stop();
        afkTimer = null;

        ConnectionEventProcessor.process(this, Closed);
    }

    private function onError(e:Dynamic)
    {
        handleError(ConnectionError(e));
    }

    private function handleError(error:NetworkingError)
    {
        switch error 
        {
            case ConnectionError(error):
                logError('Connection error:\nUUID: $id\n$error', false);
            case BytesReceived(bytes):
                logError('Unexpected bytes:\nUUID: $id\n${bytes.toHex()}', false);
            case DeserializationError(message, exception):
                logError('Event deserialization failed:\nUUID: $id\nOriginal message: $message\nException:\n${exception.message}\nNative:\n${exception.native}\nPrevious:\n${exception.previous}\nStack:${exception.stack}');
            case ProcessingError(message, exception, stack):
                var messageStr:String = Logging.stringifyMessage(message);
                emit(ServerError('Timestamp: ${Sys.time()}\nEvent: $messageStr\nException: ${exception.message} $stack'));
                logError('Error during message processing:\nUUID: $id\nEvent: $messageStr\nException:\n${exception.message}\nNative:\n${exception.native}\nPrevious:\n${exception.previous}\nStack:$stack');
        }
    }

    private function processMessage(message:MessageType)
    {
        switch message
        {
            case BytesMessage(content):
                handleError(BytesReceived(content.readAllAvailableBytes()));
            case StrMessage(content):
                processStrMessage(content);
        }
    }

    private function onAnyActivity()
    {
        if (connectionHangupTimer != null)
            connectionHangupTimer.stop();
        connectionHangupTimer = null;

        if (afkTimer != null)
            afkTimer.refresh();
        else
            afkTimer = new MovingCountdownTimer(onClientBeatTimeout, Config.config.clientHeartbeatTimeoutMs);

        if (noActivity)
        {
            noActivity = false;
            ConnectionEventProcessor.process(this, PresenceUpdated);
        }
    }

    private function processStrMessage(message:String) 
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

        onAnyActivity();

        try
        {
            processClientMessage(clientMessage);
        }
        catch (e)
        {
            handleError(ProcessingError(clientMessage.event, e, CallStack.exceptionStack(true)));
        }
    }

    private function processClientMessage(clientMessage:ClientMessage) 
    {
        var session:Null<UserSession> = Sessions.getByConnectionID(id);
        var normalized:ClientMessage = Normalizer.normalizeMessage(clientMessage);

        switch normalized
        {
            case Greet(greeting, clientBuild, minServerBuild):
                if (session != null)
                    return;

                if (silentConnectionDropTimer != null)
                    silentConnectionDropTimer.stop();
                silentConnectionDropTimer = null;

                ConnectionEventProcessor.process(this, GreetingReceived(greeting));
            case Event(id, event):
                if (session != null)
                {
                    session.updateLastClientEventID(id);
                    ClientEventProcessor.process(session, event);
                }
            case Request(id, request):
                if (session != null)
                    ClientRequestProcessor.process(session, id, request);
            case HeartBeat:
                return;
        }
    }

    private function onClientBeatTimeout() 
    {
        afkTimer = null;

        logInfo('Stopped receiving heartbeat from $id');

        connectionHangupTimer = Timer.delay(onMaxAfkDurationReached, Config.config.maxAllowedAfkMs);

        noActivity = true;
        ConnectionEventProcessor.process(this, PresenceUpdated);
    }

    private function onMaxAfkDurationReached() 
    {
        logInfo('$id had no activity for ${Config.config.maxAllowedAfkMs} ms, closing');
        close();
    }

    private function onNoGreetingAfterTimeout() 
    {
        logInfo('$id remained silent since the connection was estabilished, closing');
        close();
    }

    public function new(s:SocketImpl) 
    {
        super(s);

        var peer = s.peer();
        logInfo('$id created for ${peer.host.toString()}:${peer.port}');

        silentConnectionDropTimer = Timer.delay(onNoGreetingAfterTimeout, 1000 * 60);

        this.onopen = onOpen;
        this.onclose = onClosed;
        this.onerror = onError;
        this.onmessage = processMessage;
    }
}