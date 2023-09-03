package integration;

import net.shared.utils.PlayerRef;
import net.shared.dataobj.ChallengeData;
import net.shared.dataobj.ChallengeParams;
import utils.sieve.StringSieve;
import integration.impl.Telegram;
import integration.impl.Vk;
import integration.impl.Discord;
import utils.ds.AutoQueue;
using StringTools;

class Integration 
{
    private static var notificationTimestamps:Map<PlayerRef, AutoQueue<Float>> = [];

    public static function notifyAdmin(message:String) 
    {
        if (HotData.getInstance().alertSieve.checkPass(message))
            Telegram.notifyAdmin(message);
    }

    private static function getNotificationTimestamps(ref:PlayerRef):AutoQueue<Float>
    {
        var queue:AutoQueue<Float> = notificationTimestamps.get(ref);

        if (queue == null)
        {
            queue = new AutoQueue(3);
            notificationTimestamps.set(ref, queue);
        }

        return queue;
    }

    private static function notificationAllowed(queue:AutoQueue<Float>, currentTime:Float):Bool
    {
        var oldestTS:Null<Float> = queue.oldest();

        return oldestTS == null || currentTime - oldestTS > 60 * 5;
    }

    //TODO: Rework logic for challenges from guests
    public static function onPublicChallengeCreated(data:ChallengeData) 
    {
        var currentTime:Float = Sys.time();
        var queue:AutoQueue<Float> = getNotificationTimestamps(data.ownerRef);

        if (!notificationAllowed(queue, currentTime))
            return;
        
        queue.push(currentTime);

        Discord.onPublicChallengeCreated(data);
        Vk.onPublicChallengeCreated(data);
    }
}