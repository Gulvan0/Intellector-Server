package net;

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
        user.onDisconnected();
    }

    private function onError(e:Dynamic)
    {
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

        switch event
        {
            case RestoreSession(token):
                var restoredUser:Null<UserSession> = Auth.getUserBySessionToken(token);
                if (restoredUser != null)
                {
                    this.user = restoredUser;
                    var missedEvents = user.onReconnected(this);
                    emit(RestoreSessionResult(Restored(missedEvents)));
                }
                else
                {
                    this.user = Auth.createSession(this);
                    emit(RestoreSessionResult(NotRestored));
                    Logger.serviceLog("SOCKET", '${user.getLogReference()} attempted to restore a session with a wrong token: $token');
                }
            default:
                this.user = Auth.createSession(this);
                Orchestrator.processEvent(event, user);
        }
    }

    public function new(s:SocketImpl) 
    {
        super(s);

        this.onopen = onOpen;
        this.onclose = onClosed;
        this.onerror = onError;
        this.onmessage = processMessage;
    }
}