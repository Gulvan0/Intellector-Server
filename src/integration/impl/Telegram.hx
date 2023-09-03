package integration.impl;

import config.Config;
import sources.CommandInputSource;
import sys.thread.Thread;
import haxe.Json;
import sys.Http;

using StringTools;

class Telegram 
{
    private static var firstLaunch:Bool = true;
    private static var httpRequest:Http;

    private static var commandInput:CommandInputSource;

    public static function notifyAdmin(message:String) 
    {
        if (Config.config.tgChatID == null || httpRequest == null)
            return;

        if (message.trim().length == 0)
            message = '<empty>';

        try
        {
            Thread.create(() -> {
                try
                {
                    useMethod('sendMessage', ['chat_id' => Config.config.tgChatID, 'text' => message, 'parse_mode' => 'MarkdownV2']);
                }
                catch (e)
                {
                    Logging.error("integration/tg", 'Failed to notify admin (message = $message):\n$e', false);
                }
            });
        }
        catch (e)
        {
            Logging.error("integration/tg", 'Failed to notify admin (message = $message):\n$e', false);
        }
    }

    public static function init() 
    {
        if (Config.config.tgChatID == null || Config.config.tgToken == null)
            return;

        commandInput = new CommandInputSource(notifyAdmin);

        httpRequest = new Http(getURLPrefix() + 'getUpdates');
        httpRequest.cnxTimeout = 0.5;
        httpRequest.addParameter('allowed_updates', '["message"]');
        httpRequest.onData = processUpdates;    
    }

    public static function checkAdminChat() 
    {
        if (httpRequest == null)
            return;

        httpRequest.request();
    }

    private static function processUpdates(listStr:String) 
    {
        if (listStr == '{"ok":true,"result":[]}')
            return;

        try
        {
            var list:Array<Dynamic> = Json.parse(listStr).result;

            var maxID:Null<Int> = null;
            for (update in list)
            {
                if (Std.string(update.message.chat.id) == Config.config.tgChatID && !firstLaunch)
                    commandInput.processString(update.message.text);
    
                if (maxID == null || update.update_id > maxID)
                    maxID = update.update_id;
            }
    
            if (maxID != null)
                httpRequest.setParameter('offset', '${maxID + 1}');

            firstLaunch = false;
        }
        catch (e)
        {
            Sys.println('Failed to process updates for Telegram admin chat\nData: $listStr \nReason: $e');
        }
        
    }

    private static function useMethod(methodName:String, params:Map<String, String>, ?onError:Http->String->Void, ?postData:Null<Dynamic>) 
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

        if (postData != null)
        {
            http.setPostData(Json.stringify(postData));
            http.request(true);
        }
        else
            http.request();
    } 
    
    private static function getURLPrefix():String 
    {
        return 'https://api.telegram.org/bot' + Config.config.tgToken + '/';
    }
}