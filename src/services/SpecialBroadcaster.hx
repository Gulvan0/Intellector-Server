package services;

import net.shared.ServerEvent;
import services.util.SpecialObserverType;
import entities.UserSession;
import utils.ds.DefaultArrayMap;

class SpecialBroadcaster 
{
    private static var observerRefs:DefaultArrayMap<SpecialObserverType, String> = new DefaultArrayMap([]);

    public static function addObserver(type:SpecialObserverType, obs:UserSession) 
    {
        observerRefs.push(type, obs.getInteractionReference());
    }

    public static function removeObserver(type:SpecialObserverType, obs:UserSession) 
    {
        observerRefs.pop(type, obs.getInteractionReference());
    }

    public static function broadcast(type:SpecialObserverType, event:ServerEvent) 
    {
        for (userRef in observerRefs.get(type))
        {
            var session:Null<UserSession> = Auth.getUserByInteractionReference(userRef);

            if (session != null)
                session.emit(event);
            else
                observerRefs.pop(type, userRef);
        }
    }
}