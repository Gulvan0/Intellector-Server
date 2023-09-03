package net;

import net.shared.dataobj.Greeting;

enum ConnectionEvent 
{
    GreetingReceived(greeting:Greeting, clientBuild:Int, minServerBuild:Int);
    PresenceUpdated;
    Closed;    
}