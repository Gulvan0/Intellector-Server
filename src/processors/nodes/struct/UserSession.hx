package processors.nodes.struct;

import net.Connection;
import net.shared.dataobj.ReconnectionBundle;
import net.shared.message.ServerRequestResponse;
import net.shared.message.ServerEvent;

class UserSession
{
    private static var lastSessionID:Int = 0;

    public final sessionID:Int;
    public final token:String;

    public var connection:Null<Connection>;
    public var login:Null<String>;

    private var sentEvents:Map<Int, ServerEvent> = [];
    private var requestResponses:Map<Int, ServerRequestResponse> = [];
    private var lastSentServerEventID:Int = 0;
    private var lastProcessedClientEventID:Int = 0;

    public function equals(otherSession:UserSession):Bool 
    {
        return this.sessionID == otherSession.sessionID;    
    }

    public function getReference():String 
    {
        if (login == null)
            return '_$sessionID';
        else
            return login;
    }

    public function updateLastClientEventID(lastID:Int) 
    {
        lastProcessedClientEventID = lastID;
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
        if (connection != null)
            connection.emit(RequestResponse(requestID, response));
    }

    public function constructReconnectionBundle(lastProcessedServerEventID:Int, unansweredRequests:Array<Int>):ReconnectionBundle
    {
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

    private function generateSessionToken():String
    {
        var token:String = "_";
        for (i in 0...25)
            token += String.fromCharCode(MathUtils.randomInt(33, 126));
        
        return sessionByToken.exists(token)? generateSessionToken() : token;
    }

    public function new()
    {
        this.sessionID = ++lastSessionID;
        this.token = generateSessionToken();
    }
}