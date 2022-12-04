package net;

import net.SocketHandler;
import hx.ws.WebSocketServer;

class ServerManager 
{
    private static var server:WebSocketServer<SocketHandler>;
    
    public static function start() 
    {
        server = Config.constructServer();
        server.start();
    }

    public static function stop() 
    {
        server.stop();
    }
}