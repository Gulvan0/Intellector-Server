package services.events;

import entities.UserSession;

enum SessionManagerEvent
{
    NewSession(session:UserSession);
    SessionStatusUpdated(session:UserSession);
    SessionToBeDestroyed(session:UserSession);    
}