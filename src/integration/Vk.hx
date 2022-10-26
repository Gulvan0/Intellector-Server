package integration;

import struct.ChallengeParams;
import sys.Http;

class Vk 
{
    private static function sendNotification(message:String) 
    {
        var r = new Http('https://api.vk.com/method/messages.send');
        r.addParameter('peer_id', Config.vkChatID);
        r.addParameter('message', message);
        r.addParameter('access_token', Config.vkToken);
        r.addParameter('v', '5.81');
        r.request(true);
    }

    public static function onPublicChallengeCreated(id:Int, ownerLogin:String, params:ChallengeParams) 
    {
        var messageText:String = '🗣 Открытый вызов от $ownerLogin\n';

        if (params.rated)
            messageText += 'На рейтинг\n';
        else
            messageText += 'Без рейтинга\n';

        messageText += 'Контроль: ${params.timeControl.toString(true)}\n';

        switch params.acceptorColor
        {
            case null:
                messageText += 'Цвет: Случайно\n';
            case White:
                messageText += 'Цвет: Белыми\n';
            case Black:
                messageText += 'Цвет: Черными\n';
        }

        if (params.customStartingSituation != null)
            messageText += 'Начальная позиция: Особая\n';
        else
            messageText += 'Начальная позиция: Стандартная\n';

        messageText += 'https://intellector.info/game/?p=join/$id';

        sendNotification(messageText);
    }
}