package net;

import entities.User;
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
    private var user:User;

    public function emit(event:ServerEvent) 
    {
        Logger.logOutgoingEvent(event, id, user.login);
        send(Serializer.run(event));
    }

    private function onOpen()
    {
        Logger.serviceLog("SOCKET", '$id connected');
    }

    private function onClosed()
    {
        Logger.serviceLog("SOCKET", '$id closed');
        Orchestrator.onPlayerDisconnected(user);
    }

    private function onError(e:Dynamic)
    {
        Logger.serviceLog("SOCKET", '$id error');
        Orchestrator.onPlayerDisconnected(user);
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
                Logger.logError('Unexpected bytes:\n${bytes.toHex()}', false);
            case DeserializationError(message, exception):
                Logger.logError('Event deserialization failed:\nOriginal message: $message\n${exception.details()}');
            case ProcessingError(event, exception):
                Logger.logError('Error during event processing:\nEvent: $event\n${exception.details()}');
        }
    }

    private function processMessage(message:MessageType)
    {
        switch message
        {
            case BytesMessage(content):
                onError(BytesReceived(content.readAllAvailableBytes()));
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
            Orchestrator.processEvent(event, user);
        }
        catch (e)
        {
            handleError(ProcessingError(event, e));
        }
    }

    public function new(s:SocketImpl) 
    {
        super(s);

        this.onopen = onOpen;
        this.onclose = onClosed;
        this.onerror = onError;
        this.onmessage = processMessage;

        this.user = new User(this);
    }
}