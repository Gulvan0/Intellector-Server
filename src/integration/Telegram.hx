package integration;

import services.CommandProcessor;
import haxe.Json;
import sys.Http;

using StringTools;

class Telegram 
{
    public static function notifyAdmin(message:String) 
    {
        if (message.trim().length == 0)
            message = '<empty>';
        useMethod('sendMessage', ['chat_id' => Config.tgChatID, 'text' => message, 'parse_mode' => 'MarkdownV2'], onMethodError);
    }

    private static function onMethodError(http:Http, error:String) 
    {
        useMethod('sendMessage', ['chat_id' => Config.tgChatID, 'text' => http.responseData, 'parse_mode' => 'MarkdownV2']);
    }

    public static function checkAdminChat() 
    {
        var http = new Http(getURLPrefix() + 'getUpdates');
        http.addParameter('allowed_updates', '["message"]');
        http.onData = processUpdates;
        http.request();
    }

    private static function markConfirmed(updateID:Int) 
    {
        var http = new Http(getURLPrefix() + 'getUpdates');
        http.addParameter('offset', '$updateID');
        http.request();
    }

    private static function processUpdates(listStr:String) 
    {
        var list:Array<Dynamic> = Json.parse(listStr).result;
        for (update in list)
        {
            if (Std.string(update.message.chat.id) == Config.tgChatID)
                CommandProcessor.processCommand(update.message.text, notifyAdmin);
            markConfirmed(update.update_id + 1);
        }
    }

    private static function useMethod(methodName:String, params:Map<String, String>, ?onError:Http->String->Void) 
    {
        var http = new Http(getURLPrefix() + methodName);

        for (paramName => paramValue in params.keyValueIterator())
        {
            var escaped:String = "";
            for (i in 0...paramValue.length)
            {
                if (['_', '*', '[', ']', '(', ')', '~', '`', '>', '#', '+', '-', '=', '|', '{', '}', '.', '!'].contains(paramValue.charAt(i)))
                    escaped += '\\';
                escaped += paramValue.charAt(i);
            }
            http.addParameter(paramName, escaped);
        }
        http.onError = e -> {
            if (onError != null)
                onError(http, e);
            else
                trace(e, http.responseHeaders);
        };
        http.request();
    } 
    
    private static function getURLPrefix():String 
    {
        return 'https://api.telegram.org/bot' + Config.tgToken + '/';
    }
}