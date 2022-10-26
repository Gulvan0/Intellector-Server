package integration;

import struct.ChallengeParams;
import haxe.Http;

class Discord 
{
    private static function sendNotification(message:String) 
    {
        var r = new Http(Config.discordWebhookURL);
        r.addHeader('Content-Type', 'application/json');
        r.setPostData('{"content": "$message"}');
        r.request(true);
    }

    public static function onPublicChallengeCreated(id:Int, ownerLogin:String, params:ChallengeParams) 
    {
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
    }
}