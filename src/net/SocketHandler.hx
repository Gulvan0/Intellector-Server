package net;

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

    /* TODO: Move to entity class, but somehow leave a connection
    public var ustate:UserState;
    public var login:String;
    public var calledPlayers:Array<String>;
    public var calloutParams:Map<String, CalloutParams>;
    */

    public function emit(event:ServerEvent) 
    {
        send(Serializer.run(event));
    }

    private function onOpen()
    {
        //TODO: Fill (write log, maybe init or maybe not)
    }

    //TODO: Find out how to detect short-time disconnection and handle it properly

    private function onClosed()
    {
        //TODO: Fill (write to log, perform termination)
    }

    private function onError(e:Dynamic)
    {
        //TODO: Fill (perform termination)
        handleError(ConnectionError(e));
    }

    private function handleError(error:NetworkingError)
    {
        //TODO: Fill (log, tg notification, maybe ignore in some cases)
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
            //TODO: call Orchestrator method
        }
        catch (e)
            handleError(ProcessingError(event, e));
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