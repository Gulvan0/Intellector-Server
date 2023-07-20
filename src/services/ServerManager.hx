package services;

import config.Config;
import entities.Connection;
import hx.ws.WebSocketServer;

class ServerManager 
{
    private static var server:WebSocketServer<Connection>;
    
    public static function start(config:Config) 
    {
        server = constructServer(config);
        server.start();
    }

    public static function stop() 
    {
        server.stop();
    }

    private static function constructServer(config:Config):WebSocketServer<Connection>
    {
        var server:WebSocketServer<Connection>;

        if (config.hasSSL())
            server = new WebSocketSecureServer<Connection>(config.host, config.port, config.sslCert, config.sslKey, config.sslCert, config.maxConnections);
        else
            server = new WebSocketServer<Connection>(config.host, config.port, config.maxConnections);

        server.sleepAmount = config.sleepAmount / 1000; //ms to secs

        return server;
    }
}