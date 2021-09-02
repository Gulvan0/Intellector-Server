package subsystems;

import sys.io.Process;
using StringTools;

class Librarian 
{
    public static function getGamesByPlayer(socket:SocketHandler, login:String)
    {
        var answer:String = "";
        var process = new Process("bash", ["grepall.sh", login]);
        var output = process.stdout.readAll().toString();
        for (line in output.split("."))
        {
            var trimmed = line.trim();
            if (trimmed.length < 1)
                continue;

            var playerInfo = new Process("bash", ["grepgame.sh", trimmed, "P"]).stdout.readAll().toString().substr(3);
            var resultInfo = new Process("bash", ["grepgame.sh", trimmed, "R"]).stdout.readAll().toString().substr(3);
            answer += trimmed + "#" + resultInfo + "#" + playerInfo + "\n";
        }
        socket.emit('games_list', answer);
    }    
}