package net.shared.dataobj;

import net.shared.message.ServerRequestResponse;
import net.shared.message.ServerEvent;

class ReconnectionBundle 
{
    public final missedEvents:Map<Int, ServerEvent>;
    public final missedRequestResponses:Map<Int, ServerRequestResponse>;
    public final lastReceivedClientEventID:Int;

    public function new(missedEvents:Map<Int, ServerEvent>, missedRequestResponses:Map<Int, ServerRequestResponse>, lastReceivedClientEventID:Int)
    {
        this.missedEvents = missedEvents;
        this.missedRequestResponses = missedRequestResponses;
        this.lastReceivedClientEventID = lastReceivedClientEventID;
    }
}