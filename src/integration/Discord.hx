package integration;

import services.Logger;
import struct.ChallengeParams;
import haxe.Http;

class Discord 
{
    private static function sendNotification(message:String) 
    {
        if (Config.discordWebhookURL == null)
            return;

        var r = new Http(Config.discordWebhookURL);
        var cleanMessage:String = StringTools.replace(message, "\n", "\\n");
        r.addHeader('Content-Type', 'application/json');
        r.setPostData('{"content": "$cleanMessage"}');
        r.request(true);
    }

    public static function onPublicChallengeCreated(id:Int, ownerLogin:String, params:ChallengeParams) 
    {
        if (Config.discordWebhookURL == null)
            return;
        
        var messageText:String = 'New open challenge by **$ownerLogin**\n';

        if (params.rated)
            messageText += '*Rated*\n';
        else
            messageText += '*Unrated*\n';

        messageText += 'Time control: ${params.timeControl.toString(false)}\n';

        switch params.acceptorColor
        {
            case null:
                messageText += 'Color: Random\n';
            case White:
                messageText += 'Color: White\n';
            case Black:
                messageText += 'Color: Black\n';
        }

        if (params.customStartingSituation != null)
            messageText += 'Starting position: Custom\n';
        else
            messageText += 'Starting position: Default\n';

        messageText += 'https://intellector.info/game/?p=join/$id';

        sendNotification(messageText);
        Logger.serviceLog("INTEGRATION", 'Discord notification sent (topic: challenge $id)');
    }
}