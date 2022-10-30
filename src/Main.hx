import integration.Telegram;
import services.CommandProcessor;
import integration.Vk;
import net.SocketHandler;
import hx.ws.WebSocketServer;
using Lambda;
using StringTools;

class Main 
{
	private static var server:WebSocketServer<SocketHandler>;

	public static function main() 
	{
        Routines.onStartup();
        
        server = Config.constructServer();
        server.start();
    }
}