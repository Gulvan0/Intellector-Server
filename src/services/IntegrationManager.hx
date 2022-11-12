package services;

import struct.ChallengeParams;
import integration.Vk;
import integration.Discord;
import utils.ds.AutoQueue;

class IntegrationManager 
{
    private static var notificationTimestamps:Map<String, AutoQueue<Float>> = [];

    private static function getNotificationTimestamps(login:String):AutoQueue<Float>
    {
        var queue:AutoQueue<Float> = notificationTimestamps.get(login);

        if (queue == null)
        {
            queue = new AutoQueue(3);
            notificationTimestamps.set(login, queue);
        }

        return queue;
    }

    private static function notificationAllowed(queue:AutoQueue<Float>, currentTime:Float):Bool
    {
        var oldestTS:Null<Float> = queue.oldest();

        return oldestTS == null || currentTime - oldestTS > 60 * 5;
    }

    public static function onPublicChallengeCreated(id:Int, ownerLogin:String, params:ChallengeParams) 
    {
        var currentTime:Float = Sys.time();
        var queue:AutoQueue<Float> = getNotificationTimestamps(ownerLogin);

        if (notificationAllowed(queue, currentTime))
        {
            queue.push(currentTime);
            Discord.onPublicChallengeCreated(id, ownerLogin, params);
            Vk.onPublicChallengeCreated(id, ownerLogin, params);
        }
    }
}