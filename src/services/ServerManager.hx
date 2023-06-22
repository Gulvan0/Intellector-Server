package services;

import config.Config;
import net.SocketHandler;
import hx.ws.WebSocketServer;

class ServerManager 
{
    private static var server:WebSocketServer<SocketHandler>;
    
    public static function start(config:Config) 
    {
        server = constructServer(config);
        server.start();
    }

    public static function stop() 
    {
        server.stop();
    }

    private static function constructServer(config:Config):WebSocketServer<SocketHandler>
    {
        var server:WebSocketServer<SocketHandler>;

        if (config.hasSSL())
            server = new WebSocketSecureServer<SocketHandler>(config.host, config.port, config.sslCert, config.sslKey, config.sslCert, config.maxConnections);
        else
            server = new WebSocketServer<SocketHandler>(config.host, config.port, config.maxConnections);

        server.sleepAmount = config.sleepAmount / 1000; //ms to secs

        return server;
    }
}