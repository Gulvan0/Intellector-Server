package processors.nodes;

import utils.ds.DefaultArrayMap;
import net.shared.Subscription;
import processors.nodes.struct.UserSession;

class Subscriptions 
{
    private static var observers:DefaultArrayMap<Subscription, UserSession> = new DefaultArrayMap([]);

    private static function logInfo(message:String) 
    {
        Logging.info("data/subsriptions", message);
    }

    public static function addObserver(subscription:Subscription, obs:UserSession) 
    {
        if (!isObserver(subscription, obs))
        {
            observers.push(subscription, obs);
            logInfo('Added $obs to $subscription observer list, arrived at ${getObservers(subscription).length} observers total');
        }
        else
            logInfo('Attempted to add $obs to $subscription observer list, found out they\'re already observing');
    }

    public static function removeObserver(subscription:Subscription, obs:UserSession):Bool
    {
        var removed:Bool = observers.pop(subscription, obs);

        if (removed)
            logInfo('Removed $obs from $subscription observer list, arrived at ${getObservers(subscription).length} observers total');
        else
            logInfo('Attempted to remove $obs from $subscription observer list, yet they weren\'t observing anyway');

        return removed;
    }

    public static function broadcast(subscription:Subscription, event:ServerEvent) 
    {
        var i:Int = 0;
        for (session in observers.get(subscription))
        {
            session.emit(event);
            i++;
        }

        logInfo('Broadcasted event ${event.getName()} to $i $subscription observers');
    }

    public static function getObservers(subscription:Subscription) 
    {
        return observers.get(subscription);
    }

    public static function isObserver(subscription:Subscription, obs:UserSession) 
    {
        return observers.get(subscription).contains(obs);
    }

    public static function removeSessionFromAllSubscriptions(session:UserSession) //TODO: Call when closed
    {
        for (subscription in observers.keys())
            removeObserver(subscription, session);
    }
}