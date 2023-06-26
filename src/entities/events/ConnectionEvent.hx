package entities.events;

import net.shared.message.ClientRequest;
import net.shared.message.ClientEvent;

enum ConnectionEvent 
{
    PresenceUpdated;
    EventReceived(id:Int, event:ClientEvent);
    RequestReceived(id:Int, event:ClientRequest);
    Closed;    
}