package integration.impl;

import net.shared.dataobj.ChallengeData;
import sys.Http;

class Vk 
{
    private static function sendNotification(message:String) 
    {
        if (Config.vkChatID == null || Config.vkToken == null)
            return;

        var r = new Http('https://api.vk.com/method/messages.send');
        r.addParameter('peer_id', Config.vkChatID);
        r.addParameter('message', message);
        r.addParameter('access_token', Config.vkToken);
        r.addParameter('v', '5.81');
        r.request(true);
    }

    public static function onPublicChallengeCreated(data:ChallengeData) 
    {
        if (Config.vkChatID == null || Config.vkToken == null)
            return;
        
        var messageText:String = '🗣 Открытый вызов от ${data.ownerRef.pretty()}\n';

        if (data.params.rated)
            messageText += 'На рейтинг\n';
        else
            messageText += 'Без рейтинга\n';

        messageText += 'Контроль: ${data.params.timeControl.toString(true)}\n';

        switch data.params.acceptorColor
        {
            case null:
                messageText += 'Цвет: Случайно\n';
            case White:
                messageText += 'Цвет: Белыми\n';
            case Black:
                messageText += 'Цвет: Черными\n';
        }

        if (data.params.customStartingSituation != null)
            messageText += 'Начальная позиция: Особая\n';
        else
            messageText += 'Начальная позиция: Стандартная\n';

        messageText += 'https://intellector.info/game/?p=join/${data.id}';

        sendNotification(messageText);

        Logging.info("integration/vk", '${data.id}: sent');
    }
}