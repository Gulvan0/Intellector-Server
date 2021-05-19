package;

import haxe.Json;
import Main.Event;
import hx.ws.Buffer;
import hx.ws.Types.MessageType;
import hx.ws.SocketImpl;
import hx.ws.SecureSocketImpl;
import hx.ws.WebSocketHandler;
using Lambda;

enum UserState
{
    NotLogged;
    MainMenu;
    InGame;
}

typedef TimeControl = 
{
    var startSecs:Int;
    var bonusSecs:Int;
}

class SocketHandler extends WebSocketHandler
{

    public var ustate:UserState;
    public var login:String;
    public var calledPlayers:Array<String>;
    public var calloutTimeControls:Map<String, TimeControl>;

    public function emit(eventName:String, data:Dynamic) 
    {
        var event:Event = {name: eventName, data: data};
        send(Json.stringify(event));
    }

    public function new(s:SocketImpl) 
    {
        super(s);
        calledPlayers = [];
        calloutTimeControls = new Map();
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
            Main.handleDisconnect(this);
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
        else if (['callout', 'accept_challenge', 'cancel_callout', 'decline_challenge', 'accept_open_challenge'].has(eventName))
        {
            data.caller_login = cast(data.caller_login, String).toLowerCase();
            data.callee_login = cast(data.callee_login, String).toLowerCase();
        }
        else if (['move', 'message', 'request_timeout_check'].has(eventName))
            data.issuer_login = cast(data.issuer_login, String).toLowerCase();
        else if (eventName == 'get_challenge')
            data.challenger = cast(data.challenger, String).toLowerCase();
        else if (eventName == 'open_callout')
            data.caller_login = cast(data.caller_login, String).toLowerCase();
        else if (eventName == 'spectate')
            data.watched_login = cast(data.watched_login, String).toLowerCase();
    }

    private function handlerActive(eventName:String) 
    {
        return switch ustate 
        {
            case NotLogged: ['login', 'register', 'get_game', 'get_challenge', 'accept_open_challenge'].has(eventName);
            case MainMenu: ['callout', 'accept_challenge', 'decline_challenge', 'cancel_callout', 'open_callout', 'get_game', 'get_challenge', 'accept_open_challenge', 'spectate', 'stop_spectate'].has(eventName);
            case InGame: ['move', 'request_timeout_check', 'message'].has(eventName);
        }
    }
}