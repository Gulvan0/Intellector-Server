package net.shared.dataobj;

import net.shared.dataobj.ReconnectionBundle;
import net.shared.message.ServerRequestResponse;
import net.shared.dataobj.GameModelData;

enum GreetingResponseData
{
    ConnectedAsGuest(sessionID:Int, token:String, invalidCredentials:Bool, isShuttingDown:Bool);
    Logged(sessionID:Int, token:String, incomingChallenges:Array<ChallengeData>, isShuttingDown:Bool);
    Reconnected(bundle:ReconnectionBundle);
    NotReconnected;
    OutdatedClient;
    OutdatedServer;
}