package services.events;

import entities.util.SessionStatus;
import entities.UserSession;

enum SessionManagerEvent
{
    NewSession(session:UserSession);
    SessionLoginUpdated(session:UserSession);
    SessionStatusUpdated(session:UserSession);
    PlayerStatusUpdated(login:String, status:SessionStatus);
    SessionToBeDestroyed(session:UserSession);    
}