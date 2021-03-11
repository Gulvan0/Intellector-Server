package;

import haxe.Json;
import Main.Event;
import hx.ws.Buffer;
import hx.ws.Types.MessageType;
import hx.ws.SocketImpl;
import hx.ws.WebSocketHandler;
using Lambda;

enum UserState
{
    NotLogged;
    MainMenu;
    InGame;
}

class SocketHandler extends WebSocketHandler
{

    public var ustate:UserState;
    public var calledPlayers:Array<String>;

    public function emit(eventName:String, data:Dynamic) 
    {
        var event:Event = {name: eventName, data: data};
        send(Json.stringify(event));
    }

    public function new(s: SocketImpl) 
    {
        super(s);
        calledPlayers = [];
        onopen = () -> {
            ustate = NotLogged;
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
                    processEvent(content);
            }
        }
    }

    private function processEvent(message:String) 
    {
        var event:Event = Json.parse(message);

        if (!handlerActive(event.name))
            return;

        lowerLogin(event.name, event.data);
        Main.handleEvent(this, event.name, event.data);
    }

    private function lowerLogin(eventName, data) 
    {
        if (['login', 'register'].has(eventName))
            data.login = cast(data.login, String).toLowerCase();
        else if (['callout', 'accept_challenge', 'cancel_callout', 'decline_challenge'].has(eventName))
        {
            data.caller_login = cast(data.caller_login, String).toLowerCase();
            data.callee_login = cast(data.callee_login, String).toLowerCase();
        }
        else if ('move' == eventName)
            data.issuer_login = cast(data.issuer_login, String).toLowerCase();
    }

    private function handlerActive(eventName:String) 
    {
        return switch ustate 
        {
            case NotLogged: ['login', 'register'].has(eventName);
            case MainMenu: ['callout', 'accept_challenge', 'cancel_callout'].has(eventName);
            case InGame: ['move'].has(eventName);
        }
    }
}