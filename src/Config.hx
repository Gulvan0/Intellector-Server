package;

import services.Logger;
import yaml.Parser;
import yaml.util.ObjectMap.AnyObjectMap;
import yaml.util.StringMap;
import yaml.Yaml;
import services.Storage;
import hx.ws.WebSocketSecureServer;
import net.SocketHandler;
import hx.ws.WebSocketServer;
import argparse.Namespace;
import argparse.ArgParser;
import sys.ssl.Key;
import sys.ssl.Certificate;

class Config
{
    public static var sslCert:Null<Certificate>;
    public static var sslKey:Null<Key>;
    public static var host:String = "localhost";
    public static var port:Int = 5000;
    public static var logMask:Int = 0;
    public static var printLog:Bool = false;
    public static var maxConnections:Int = 1000;
    public static var sleepAmount:Float = 0.5;

    public static var discordWebhookURL:Null<String>;
    public static var tgToken:Null<String>;
    public static var tgChatID:Null<String>;
    public static var vkToken:Null<String>;
    public static var vkChatID:Null<String>;

    public static var defaultElo:Int = 1200;
    public static var maxEloLogSlope:Float = 7.0;
    public static var normalEloLogSlope:Float = 4.0;
    public static var calibrationGamesCount:Int = 12;

    public static var secsAddedManually:Int = 15;

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

    private static function loadFromYAML() 
    {
        var contents:String = Storage.read(ServerConfig);
        var data:AnyObjectMap = new AnyObjectMap();

        try
        {
            data = Yaml.parse(contents);
        }
        catch (e)
        {
            throw "Cannot parse config.yaml due to the following exception:\n" + e;
        }

        if (data.exists("host"))
            host = data.get("host");

        if (data.exists("port"))
            port = data.get("port");

        if (data.exists("cert-path"))
            sslCert = Certificate.loadFile(data.get("cert-path"));

        if (data.exists("key-path"))
            sslKey = Key.loadFile(data.get("key-path"));

        if (data.exists("max-connections"))
            maxConnections = data.get("max-connections");

        if (data.exists("sleep"))
            sleepAmount = data.get("sleep");

        if (data.exists("elo"))
        {
            var eloMap:AnyObjectMap = data.get("elo");

            if (eloMap.exists("default"))
                defaultElo = eloMap.get("default");

            if (eloMap.exists("max-logslope"))
                maxEloLogSlope = eloMap.get("max-logslope");

            if (eloMap.exists("normal-logslope"))
                normalEloLogSlope = eloMap.get("normal-logslope");

            if (eloMap.exists("calibration-games"))
                calibrationGamesCount = eloMap.get("calibration-games");
        }

        if (data.exists("rules"))
        {
            var rulesMap:AnyObjectMap = data.get("rules");

            if (rulesMap.exists("secs-added-manually"))
                secsAddedManually = rulesMap.get("secs-added-manually");
        }

        if (data.exists("integrations"))
        {
            var integrationsMap:AnyObjectMap = data.get("integrations");

            if (integrationsMap.exists("discord"))
            {
                var discData:AnyObjectMap = integrationsMap.get("discord");

                if (discData.exists("webhook-url"))
                    discordWebhookURL = discData.get("webhook-url");
            }

            if (integrationsMap.exists("telegram"))
            {
                var tgData:AnyObjectMap = integrationsMap.get("telegram");

                if (tgData.exists("bot-token"))
                    tgToken = tgData.get("bot-token");
                    
                if (tgData.exists("admin-chat-id"))
                    tgChatID = Std.string(tgData.get("admin-chat-id"));
            }

            if (integrationsMap.exists("vk"))
            {
                var vkData:AnyObjectMap = integrationsMap.get("vk");

                if (vkData.exists("token"))
                    vkToken = vkData.get("token");
                    
                if (vkData.exists("chat-id"))
                    vkChatID = Std.string(vkData.get("chat-id"));
            }
        }
    }

    private static function loadFromCLIArgs() 
    {
        var parser:ArgParser = new ArgParser();
        parser.addArgument({flags: ["-i"], help: "Include INFO-level messages in the stdout"});
        parser.addArgument({flags: ["-m"], help: "Include DATA-level messages in the stdout"});
        parser.addArgument({flags: ["-d"], help: "Include DEBUG-level messages in the stdout"});
        parser.addArgument({flags: ["-l"], help: "Include LOG-level messages in the stdout"});

        var args:Array<String> = Sys.args();
        var namespace:Namespace = parser.parse(args);

        if (namespace.exists("i"))
            logMask |= hx.ws.Log.INFO;
        if (namespace.exists("m"))
            logMask |= hx.ws.Log.DATA;
        if (namespace.exists("d"))
            logMask |= hx.ws.Log.DEBUG;

        printLog = namespace.exists("l");
    }

    public static function load() 
    {
        loadFromCLIArgs();
        loadFromYAML();
    }
}