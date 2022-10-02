import net.SocketHandler;
import haxe.Serializer;
import hx.ws.WebSocketSecureServer;
import hx.ws.Log;
import hx.ws.WebSocketServer;
using Lambda;
using StringTools;

class Main 
{
	private static var server:WebSocketServer<SocketHandler>;

	public static function main() 
	{
        Serializer.USE_ENUM_INDEX = true;
        Configuration.load();

        Log.mask = Configuration.logMask;

        Routines.onStartup();
        server = Configuration.constructServer();
        server.start();
    }
}