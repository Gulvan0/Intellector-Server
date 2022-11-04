package services;

import net.shared.ServerEvent;
import services.util.SpecialObserverType;
import entities.UserSession;
import utils.ds.DefaultArrayMap;

class SpecialBroadcaster 
{
    private static var observers:DefaultArrayMap<SpecialObserverType, UserSession> = new DefaultArrayMap([]);

    public static function addObserver(type:SpecialObserverType, obs:UserSession) 
    {
        if (!observers.get(type).contains(obs))
            observers.push(type, obs);
    }

    public static function removeObserver(type:SpecialObserverType, obs:UserSession) 
    {
        observers.pop(type, obs);
    }

    public static function broadcast(type:SpecialObserverType, event:ServerEvent) 
    {
        for (session in observers.get(type))
            session.emit(event);
    }

    public static function handleSessionDestruction(user:UserSession) 
    {
        for (type in SpecialObserverType.createAll())
            removeObserver(type, user);
    }
}