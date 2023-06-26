package services;

import net.shared.message.ServerEvent;
import net.shared.Subscription;
import entities.UserSession;
import utils.ds.DefaultArrayMap;

class SubscriptionManager extends Service
{
    private var observers:DefaultArrayMap<Subscription, UserSession> = new DefaultArrayMap([]);

    public function getServiceSlug():Null<String>
    {
        return "subscription";
    }

    public function addObserver(subscription:Subscription, obs:UserSession) 
    {
        if (!isObserver(subscription, obs))
        {
            observers.push(subscription, obs);
            logInfo('Added $obs to $subscription observer list, arrived at ${getObservers(subscription).length} observers total');
        }
        else
            logInfo('Attempted to add $obs to $subscription observer list, found out they\'re already observing');
    }

    public function removeObserver(subscription:Subscription, obs:UserSession):Bool
    {
        var removed:Bool = observers.pop(subscription, obs);

        if (removed)
            logInfo('Removed $obs from $subscription observer list, arrived at ${getObservers(subscription).length} observers total');
        else
            logInfo('Attempted to remove $obs from $subscription observer list, yet they weren\'t observing anyway');

        return removed;
    }

    public function broadcast(subscription:Subscription, event:ServerEvent) 
    {
        var i:Int = 0;
        for (session in observers.get(subscription))
        {
            session.emit(event);
            i++;
        }

        logInfo('Broadcasted event ${event.getName()} to $i $subscription observers');
    }

    public function getObservers(subscription:Subscription) 
    {
        return observers.get(subscription);
    }

    public function isObserver(subscription:Subscription, obs:UserSession) 
    {
        return observers.get(subscription).contains(obs);
    }

    public function onSessionDestroyed(user:UserSession) 
    {
        for (subscription in observers.keys())
            removeObserver(subscription, user);
    }

    public function new(orchestrator:Orchestrator)
    {
        super(orchestrator);
    }
}