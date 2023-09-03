package processors;

import processors.actions.SessionConnection;
import net.shared.utils.DateUtils;
import net.shared.utils.Build;
import config.Config;
import net.shared.dataobj.Greeting;
import net.ConnectionEvent;
import net.Connection;

class ConnectionEventProcessor 
{
    private static function logInfo(message:String) 
    {
        Logging.info("processor/connectionEvent", message);
    }

    public static function process(connection:Connection, event:ConnectionEvent) 
    {
        //TODO
        switch event 
        {
            case GreetingReceived(greeting, clientBuild, minServerBuild):
                onGreeting(connection, greeting, clientBuild, minServerBuild);
            case PresenceUpdated:
            case Closed:
        }
    } 

    private static function onGreeting(connection:Connection, greeting:Greeting, clientBuild:Int, minServerBuild:Int)
    {
        if (clientBuild < Config.config.minClientVer)
        {
            connection.emit(GreetingResponse(OutdatedClient));

            var actualDatetime:String = DateUtils.strDatetimeFromSecs(clientBuild);
            var minDatetime:String = DateUtils.strDatetimeFromSecs(Config.config.minClientVer);
            logInfo('Refusing to connect ${connection.id}: outdated client ($actualDatetime < $minDatetime)');

            return;
        }

        if (Build.buildTime() < minServerBuild)
        {
            connection.emit(GreetingResponse(OutdatedServer));

            var actualDatetime:String = DateUtils.strDatetimeFromSecs(Build.buildTime());
            var minDatetime:String = DateUtils.strDatetimeFromSecs(minServerBuild);
            logInfo('Refusing to connect ${connection.id}: outdated server ($actualDatetime < $minDatetime)');

            return;
        }

        switch greeting
        {
            case Simple:
                SessionConnection.processSimpleGreeting(connection);
            case Login(login, password):
                SessionConnection.processLoginGreeting(connection, login, password);
            case Reconnect(token, lastProcessedServerEventID, unansweredRequests):
                SessionConnection.processReconnectGreeting(connection, token, lastProcessedServerEventID, unansweredRequests);
        }
    }
}