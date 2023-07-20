package entities.events;

import net.shared.dataobj.Greeting;
import net.shared.message.ClientRequest;
import net.shared.message.ClientEvent;

enum ConnectionEvent 
{
    GreetingReceived(greeting:Greeting);
    EventReceived(id:Int, event:ClientEvent);
    RequestReceived(id:Int, event:ClientRequest);
    PresenceUpdated;
    Closed;    
}