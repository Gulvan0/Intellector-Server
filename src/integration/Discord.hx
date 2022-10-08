package integration;

import haxe.Http;

class Discord 
{
    public static function sendNotification(message:String) 
    {
        var r = new Http(Config.discordWebhookURL);
        r.addHeader('Content-Type', 'application/json');
        r.setPostData('{"content": "$message"}');
        r.request(true);
    }  
}