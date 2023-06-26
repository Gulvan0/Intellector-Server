package entities;

import net.shared.dataobj.ReconnectionBundle;
import entities.events.ConnectionEvent;
import entities.events.SessionEvent;
import entities.util.SessionStatus;
import utils.MovingCountdownTimer;
import net.shared.message.ServerRequestResponse;
import net.shared.message.ServerMessage;
import net.shared.utils.UnixTimestamp;
import services.PageManager;
import services.LoginManager;
import services.GameManager;
import haxe.Timer;
import services.ChallengeManager;
import haxe.Json;
import net.SocketHandler;

class UserSession
{
    public var connection:Null<SocketHandler>;
    public var sessionID(default, null):Int;
    public var login:Null<String>;

    private var sentEvents:Map<Int, ServerEvent> = [];
    private var requestResponses:Map<Int, ServerRequestResponse> = [];
    public var lastSentServerEventID(default, null):Int = 0;
    public var lastProcessedClientEventID:Int = 0;

    private var eventHandler:SessionEvent->Void;

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

    public function handleConnectionEvent(event:ConnectionEvent) 
    {
        switch event 
        {
            case PresenceUpdated:
                eventHandler(StatusChanged);
            case EventReceived(id, event):
                //TODO: Orchestrator
            case RequestReceived(id, event):
                //TODO: Orchestrator
            case Closed:
                //TODO: Logger.serviceLog("SESSION", '$this disconnected (skipDisconnectionProcessing = $skipDisconnectionProcessing)');

                this.connection = null;
                eventHandler(StatusChanged);
        }
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
        //TODO: Logger.serviceLog("SESSION", '$this reconnected');
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

    public function new(connection:SocketHandler, sessionID:Int, sessionEventHandler:UserSession->SessionEvent->Void)
    {
        this.connection = connection;
        this.sessionID = sessionID;
        this.eventHandler = sessionEventHandler.bind(this);
    }
}