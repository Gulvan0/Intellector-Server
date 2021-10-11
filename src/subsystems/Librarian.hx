package subsystems;

import haxe.Json;
import sys.io.Process;
using StringTools;

typedef GameOverview = 
{
    var id:Int;
    var whiteLogin:String;
    var blackLogin:String;
    var winnerColorLetter:String;
    var outcomeCode:String;
}

class Librarian 
{
    public static function getGamesByPlayer(socket:SocketHandler, login:String, pageSize:Int, after:Int)
    {
        var playersRegexp:EReg = ~/#P\|(.*?):(.*?);/;
        var resultRegexp:EReg = ~/#R\|([wbd])\/(...)/;

        var gamelist:Array<GameOverview> = [];
        for (gameID in Data.getPlayerdata(login).games.slice(after, after + pageSize))
        {
            var log:String = Data.getLog(gameID);
            playersRegexp.match(log);
            resultRegexp.match(log);
            gamelist.push({
                id: gameID,
                whiteLogin: playersRegexp.matched(1),
                blackLogin: playersRegexp.matched(2),
                winnerColorLetter: resultRegexp.matched(1),
                outcomeCode: resultRegexp.matched(2)
            });
        }
        socket.emit('games_list', Json.stringify(gamelist));
    }    
}