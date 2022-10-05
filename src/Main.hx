import sys.thread.Thread;
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
        Routines.onStartup();
        
        server = Configuration.constructServer();
        server.start();
    }
}