package services.util;

import net.shared.dataobj.ReconnectionBundle;

enum ReconnectionResult 
{
    Reconnected(bundle:ReconnectionBundle);
    WrongToken;    
}