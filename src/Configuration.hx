package;

import hx.ws.WebSocketSecureServer;
import net.SocketHandler;
import hx.ws.WebSocketServer;
import hx.ws.Log;
import argparse.Namespace;
import argparse.ArgParser;
import sys.ssl.Key;
import sys.ssl.Certificate;

class Configuration
{
    public static var sslCert:Null<Certificate>;
    public static var sslKey:Null<Key>;
    public static var host:String = "localhost";
    public static var port:Int = 5000;
    public static var logMask:Int = 0;
    public static var maxConnections:Int = 1000;
    public static var sleepAmount:Float = 0.5;

    public static function hasSSL():Bool
    {
        return sslCert != null && sslKey != null;
    }

    public static function constructServer():WebSocketServer<SocketHandler>
    {
        var server:WebSocketServer<SocketHandler>;

        if (hasSSL())
            server = new WebSocketSecureServer<SocketHandler>(host, port, sslCert, sslKey, sslCert, maxConnections);
        else
            server = new WebSocketServer<SocketHandler>(host, port, maxConnections);

        server.sleepAmount = sleepAmount / 1000; //ms to secs

        return server;
    }

    public static function load() 
    {
        var parser:ArgParser = new ArgParser();
        parser.addArgument({flags: ["--host", "-h"], numArgs: 1, optional: true, help: "Server host"});
        parser.addArgument({flags: ["--port", "-p"], numArgs: 1, optional: true, help: "Server port"});
        parser.addArgument({flags: ["-i"], help: "Include INFO-level messages in the stdout"});
        parser.addArgument({flags: ["-m"], help: "Include DATA-level messages in the stdout"});
        parser.addArgument({flags: ["-d"], help: "Include DEBUG-level messages in the stdout"});
        parser.addArgument({flags: ["--cert", "-c"], numArgs: 1, optional: true, help: "Path to the SSL certificate (.pem extension)"});
        parser.addArgument({flags: ["--key", "-k"], numArgs: 1, optional: true, help: "Path to the private SSL key"});
        parser.addArgument({flags: ["--maxconn"], numArgs: 1, optional: true, help: "Maximum number of simultaneous connections"});
        parser.addArgument({flags: ["--sleep"], numArgs: 1, optional: true, help: "Sleep amount (in ms)"});

        var args:Array<String> = Sys.args();
        var namespace:Namespace = parser.parse(args);

        if (namespace.exists("host"))
            host = namespace.get("host")[0];

        if (namespace.exists("port"))
        {
            var parsedPort:Null<Int> = Std.parseInt(namespace.get("port")[0]);
            if (parsedPort == null)
                throw "Port should be an integer value";
            else
                port = parsedPort;
        }

        if (namespace.exists("i"))
            logMask |= Log.INFO;
        if (namespace.exists("m"))
            logMask |= Log.DATA;
        if (namespace.exists("d"))
            logMask |= Log.DEBUG;

        if (namespace.exists("cert"))
            sslCert = Certificate.loadFile(namespace.get("cert")[0]);

        if (namespace.exists("key"))
            sslKey = Key.loadFile(namespace.get("key")[0]);

        if (namespace.exists("maxconn"))
        {
            var parsedMaxConn:Null<Int> = Std.parseInt(namespace.get("maxconn")[0]);
            if (parsedMaxConn == null)
                throw "MaxConn should be an integer value";
            else
                maxConnections = parsedMaxConn;
        }

        if (namespace.exists("sleep"))
        {
            var parsedSleep:Null<Float> = Std.parseFloat(namespace.get("sleep")[0]);
            if (parsedSleep == null)
                throw "Sleep should be a valid Float value";
            else
                sleepAmount = parsedSleep;
        }
    }
}