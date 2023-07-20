package entities;

import net.shared.message.ServerEvent;
import net.shared.dataobj.ReconnectionBundle;
import entities.Connection;
import entities.util.SessionStatus;
import utils.MovingCountdownTimer;
import net.shared.message.ServerRequestResponse;
import net.shared.message.ServerMessage;
import net.shared.utils.UnixTimestamp;
import services.PageManager;
import services.GameManager;
import haxe.Timer;
import services.ChallengeManager;
import haxe.Json;

class UserSession
{
    public final sessionID:Int;
    public final token:String;

    public var connection:Null<Connection>;
    public var login:Null<String>;

    private var sentEvents:Map<Int, ServerEvent> = [];
    private var requestResponses:Map<Int, ServerRequestResponse> = [];
    public var lastSentServerEventID(default, null):Int = 0;
    public var lastProcessedClientEventID:Int = 0;

    public function equals(otherSession:UserSession):Bool 
    {
        return this.sessionID == otherSession.sessionID;    
    }

    public function getSessionStatus():SessionStatus
    {
        if (connection == null)
            return NotConnected;
        else if (connection.noActivity)
            return Away;
        else
            return Active;
    }

    public function getReference():String 
    {
        if (login == null)
            return '_$sessionID';
        else
            return login;
    }

    public function emit(event:ServerEvent) 
    {
        lastSentServerEventID++;
        sentEvents.set(lastSentServerEventID, event);

        if (connection != null)
            connection.emit(Event(lastSentServerEventID, event));
    }

    public function respondToRequest(requestID:Int, response:ServerRequestResponse) 
    {
        requestResponses.set(requestID, response);
        emit(RequestResponse(requestID, response));
    }

    public function onReconnected(connection:SocketHandler, lastProcessedServerEventID:Int, unansweredRequests:Array<Int>):ReconnectionBundle
    {
        Logging.info("SESSION", '$this reconnected');

        this.connection = connection;

        var nextEventID:Int = lastProcessedServerEventID + 1;
        var missedEvents:Map<Int, ServerEvent> = [];

        while (sentEvents.exists(nextEventID))
        {
            missedEvents.set(nextEventID, sentEvents.get(nextEventID));
            nextEventID++;
        }

        var missedRequestResponses:Map<Int, ServerRequestResponse> = [];

        for (requestID in unansweredRequests)
            if (requestResponses.exists(requestID))
                missedRequestResponses.set(requestID, requestResponses[requestID]);

        return new ReconnectionBundle(missedEvents, missedRequestResponses, lastProcessedClientEventID);
    }

    public inline function toString():String
    {
        return getReference();    
    }

    public function new(connection:SocketHandler, sessionID:Int, token:String, sessionEventHandler:UserSession->SessionEvent->Void)
    {
        this.connection = connection;
        this.sessionID = sessionID;
        this.token = token;
        this.eventHandler = sessionEventHandler.bind(this);
    }
}