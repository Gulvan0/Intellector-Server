package integration.impl;

import net.shared.dataobj.ChallengeData;
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

    public static function onPublicChallengeCreated(data:ChallengeData) 
    {
        if (Config.discordWebhookURL == null)
            return;
        
        var messageText:String = 'New open challenge by **${data.ownerRef.pretty()}**\n';

        if (data.params.rated)
            messageText += '*Rated*\n';
        else
            messageText += '*Unrated*\n';

        messageText += 'Time control: ${data.params.timeControl.toString(false)}\n';

        switch data.params.acceptorColor
        {
            case null:
                messageText += 'Color: Random\n';
            case White:
                messageText += 'Color: White\n';
            case Black:
                messageText += 'Color: Black\n';
        }

        if (data.params.customStartingSituation != null)
            messageText += 'Starting position: Custom\n';
        else
            messageText += 'Starting position: Default\n';

        messageText += 'https://intellector.info/game/?p=join/${data.id}';

        sendNotification(messageText);

        Logging.info("integration/discord", '${data.id}: sent');
    }
}