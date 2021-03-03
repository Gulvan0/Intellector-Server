package;

import haxe.Json;
import Main.Event;
import hx.ws.Buffer;
import hx.ws.Types.MessageType;
import hx.ws.SocketImpl;
import hx.ws.WebSocketHandler;

class SocketHandler extends WebSocketHandler
{
    public function new(s: SocketImpl) 
    {
        super(s);
        onopen = () -> {
            trace(id + ". OPEN");
        }
        onclose = () -> {
            trace(id + ". CLOSE");
            Main.handleDisconnect(this);
        }
        onerror = (error) -> {
            trace(id + ". ERROR: " + error);
        }

        onmessage = (message: MessageType) -> {
            switch (message) 
            {
                case BytesMessage(content):
                    trace("Unexpected bytes: " + content.readAllAvailableBytes());
                case StrMessage(content):
                    trace(content.toString());
                    var event:Event = Json.parse(content);
                    Main.handleEvent(this, event.name, event.data);
            }
        }
    }

    public function emit(eventName:String, data:Dynamic) 
    {
        var event:Event = {name: eventName, data: data};
        send(Json.stringify(event));
    }
}