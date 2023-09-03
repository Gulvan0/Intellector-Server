package config;

import sys.io.File;
import yaml.Parser;
import yaml.util.ObjectMap.AnyObjectMap;
import yaml.util.StringMap;
import yaml.Yaml;
import argparse.Namespace;
import argparse.ArgParser;
import sys.ssl.Key;
import sys.ssl.Certificate;

using config.ValueConverters;

class Config
{
    public static var config:Config;

    public final sslCert:Null<Certificate>;
    public final sslKey:Null<Key>;
    public final host:String;
    public final port:Int;
    public final minClientVer:Int;
    public final logMask:Int;
    public final printLog:Bool;
    public final maxConnections:Int;
    public final sleepAmount:Float;

    public final clientHeartbeatTimeoutMs:Int;
    public final maxAllowedAfkMs:Int;

    public final discordWebhookURL:Null<String>;
    public final tgToken:Null<String>;
    public final tgChatID:Null<String>;
    public final vkToken:Null<String>;
    public final vkChatID:Null<String>;

    public final defaultElo:Int;
    public final maxEloLogSlope:Float;
    public final normalEloLogSlope:Float;
    public final calibrationGamesCount:Int;

    public final mysqlHost:String;
    public final mysqlPort:Int;
    public final mysqlUser:String;
    public final mysqlPass:String;

    public static function load() 
    {
        var rawConfig:String;

        try
        {
            rawConfig = File.getContent("./config.yaml");
        }
        catch (e)
        {
            throw "Cannot read config.yaml due to the following exception:\n" + e;
        }

        config = new Config(rawConfig);
    }

    public function hasSSL():Bool
    {
        return sslCert != null && sslKey != null;
    }
    
    private function loadOption(parsedYaml:AnyObjectMap, path:String, required:Bool):Null<Dynamic>
    {
        var pathParts:Array<String> = path.split('/');

        var map:AnyObjectMap = parsedYaml;

        for (i => part in pathParts.keyValueIterator())
        {
            if (map.exists(part))
                if (i < part.length - 1)
                    map = map.get(part);
                else
                    return map.get(part);
            else if (required)
                throw 'Required config option not present: ${path}';
            else
                return null;
        }
    }

    private function loadFromYAML() 
    {
        var data:AnyObjectMap = new AnyObjectMap();

        try
        {
            data = Yaml.parse(rawYamlConfig);
        }
        catch (e)
        {
            throw "Cannot parse config.yaml due to the following exception:\n" + e;
        }

        sslCert = loadOption(data, "cert-path", false)?.asCertificate();
        sslKey = loadOption(data, "key-path", false)?.asKey();

        host = loadOption(data, "host", false)?.asString() ?? "localhost";
        port = loadOption(data, "port", false)?.asInt() ?? 5000;

        minClientVer = loadOption(data, "min-client-build", false)?.asInt() ?? 0;
        maxConnections = loadOption(data, "max-connections", false)?.asInt() ?? 1000;
        sleepAmount = loadOption(data, "sleep", false)?.asFloat() ?? 0.5;

        clientHeartbeatTimeoutMs = loadOption(data, "client-heartbeat-timeout", false)?.asInt() ?? 1000 * 60 * 5;
        maxAllowedAfkMs = loadOption(data, "max-allowed-afk", false)?.asInt() ?? 1000 * 60 * 60 * 24;

        discordWebhookURL = loadOption(data, "integrations/discord/", false)?.asString();
        tgToken = loadOption(data, "integrations/telegram/bot-token", false)?.asString();
        tgChatID = loadOption(data, "integrations/telegram/admin-chat-id", false)?.asString();
        vkToken = loadOption(data, "integrations/vk/token", false)?.asString();
        vkChatID = loadOption(data, "integrations/vk/chat-id", false)?.asString();

        defaultElo = loadOption(data, "elo/default", false)?.asInt() ?? 1200;
        maxEloLogSlope = loadOption(data, "elo/max-logslope", false)?.asFloat() ?? 7.0;
        normalEloLogSlope = loadOption(data, "elo/normal-logslope", false)?.asFloat() ?? 4.0;
        calibrationGamesCount = loadOption(data, "elo/calibration-games", false)?.asInt() ?? 12;

        mysqlHost = loadOption(data, "mysql/host", true).asString();
        mysqlPort = loadOption(data, "mysql/port", true).asInt();
        mysqlUser = loadOption(data, "mysql/user", true).asString();
        mysqlPass = loadOption(data, "mysql/pass", false)?.asString() ?? "";
    }

    private function loadFromCLIArgs() 
    {
        var parser:ArgParser = new ArgParser();
        parser.addArgument({flags: ["-i"], help: "Include INFO-level messages in the stdout"});
        parser.addArgument({flags: ["-d"], help: "Include DEBUG-level messages in the stdout"});

        var args:Array<String> = Sys.args();
        var namespace:Namespace = parser.parse(args);

        logMask = 0;
        if (namespace.exists("i"))
            logMask |= hx.ws.Log.INFO;
        if (namespace.exists("d"))
            logMask |= hx.ws.Log.DEBUG;

        printLog = namespace.exists("i");
    }

    public function new(rawYamlConfig:String)
    {
        loadFromCLIArgs();
        loadFromYAML(rawYamlConfig);
    }
}