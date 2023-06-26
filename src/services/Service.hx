package services;

import services.events.GenericServiceEvent;
import entities.UserSession;

abstract class Service 
{
    private final orchestrator:Orchestrator;

    public abstract function getServiceSlug():Null<String>;

    public abstract function handleServiceEvent(event:GenericServiceEvent):Void;

    private function logInfo(message:String) 
    {
        Logging.info(getServiceSlug(), message);
    }

    private function logError(message:String, ?notifyAdmin:Bool) 
    {
        Logging.error(getServiceSlug(), message, notifyAdmin);
    }

    public function new(orchestrator:Orchestrator)
    {
        this.orchestrator = orchestrator;
    }
}