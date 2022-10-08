package integration;

import sys.Http;

class Vk 
{
    public static function sendNotification(message:String) 
    {
        var r = new Http('https://api.vk.com/method/messages.send');
        r.addParameter('peer_id', Config.vkChatID);
        r.addParameter('message', message);
        r.addParameter('access_token', Config.vkToken);
        r.addParameter('v', '5.81');
        r.request(true);
    }
}