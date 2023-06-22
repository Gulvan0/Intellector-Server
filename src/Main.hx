import sys.thread.Thread;
import hx.ws.Log;
import integration.Telegram;
import database.Database;
import services.IntegrationManager;
import haxe.Serializer;
import services.ServerManager;

class Main 
{
    public static var database:Database;

	public static function main() 
	{
        Serializer.USE_ENUM_INDEX = true;

        Config.load();
        Log.mask = Config.logMask;

        database = new Database();
        Logging.init(database);

        //TODO: Write to the launch table

        IntegrationManager.init();
        Telegram.init();

        Routines.initTimer(1000, Telegram.checkAdminChat, 'checkAdminTG');
        Thread.createWithEventLoop(Routines.watchStdin);

        Telegram.notifyAdmin("Server started");
        ServerManager.start();
    }
}