import Game.Color;
import hx.ws.Log;
import hx.ws.WebSocketServer;
import haxe.crypto.Md5;
using Lambda;
using StringTools;

typedef Event =
{
    var name:String;
    var data:Dynamic;
}

enum GameOverReason
{
    Mate;
    Agreement;
    Timeout;
    Abandon;
}

typedef MoveData =
{
    var issuer_login:String;
    var fromI:Int;
    var toI:Int;
    var fromJ:Int;
    var toJ:Int;
}

class Main 
{

    public static var currID(get, null):Int;
    private static var passwords:Map<String, String> = [];
	private static var loggedPlayers:Map<String, SocketHandler> = [];
	private static var games:Map<String, Game> = [];

	public static function main() 
	{    
        currID = Std.parseInt(Data.read("currid.txt"));
        parsePasswords(Data.read("playerdata.txt"));

        Log.mask = Log.INFO | Log.DEBUG | Log.DATA;
        var server = new WebSocketServer<SocketHandler>("localhost", 5000, 100);
        server.start();
    }

    public static function get_currID() 
    {
        currID++;
        Data.overwrite("currid.txt", '$currID');
        return currID;
    }

    private static function parsePasswords(pwdData:String) 
    {
        for (line in pwdData.split(';'))
            if (line.length > 3)
            {
                var pair = line.split(':');
                var login = pair[0].trim();
                var pwdMD5 = pair[1].trim();
                passwords[login] = pwdMD5;
            }
    }

    public static function handleEvent(sender:SocketHandler, eventName:String, data:Dynamic) 
    {
        switch eventName
        {
            case 'login':
                onLoginAttempt(sender, data);
            case 'register':
                onRegisterAttempt(sender, data);
            case 'callout':
                onCallout(sender, data);
            case 'accept_challenge':
                onAcceptChallenge(sender, data);
            case 'cancel_callout':
                onCancelCallout(sender, data);
            case 'move':
                onMove(sender, data);
            default:
                trace("Unexpected event: " + eventName);
        }
    }

    public static function handleDisconnect(socket:SocketHandler) 
    {
        for (k => v in loggedPlayers.keyValueIterator())
            if (v.id == socket.id)
            {
                loggedPlayers.remove(k);
                handleDisconnectionForGame(k);
                return;
            }
    }

    private static function onLoginAttempt(socket:SocketHandler, data) 
    {
        if (passwords.get(data.login) == Md5.encode(data.password))
        {
            onLogged(socket, data.login);
            socket.emit('login_result', 'success');
        }
        else 
            socket.emit('login_result', 'fail');
    }

    private static function onRegisterAttempt(socket:SocketHandler, data) 
    {
        if (!passwords.exists(data.login))
        {
            var md5 = Md5.encode(data.password);
            Data.append("playerdata.txt", '${data.login}:${md5};\n');
            passwords[data.login] = md5;
            onLogged(socket, data.login);
            socket.emit('register_result', 'success');
        }
        else 
            socket.emit('register_result', 'fail');
    }

    private static function onLogged(socket:SocketHandler, login:String)
    {
        loggedPlayers[login] = socket;
        socket.ustate = MainMenu;
    }

    private static function onCallout(socket:SocketHandler, data)
    {
        if (data.callee_login != data.caller_login)
            if (loggedPlayers.exists(data.callee_login))
                if (!games.exists(data.callee_login))
                    if (loggedPlayers[data.caller_login].calledPlayers.has(data.callee_login))
                        socket.emit('repeated_callout', {callee: data.callee_login});
                    else
                    {
                        loggedPlayers[data.caller_login].calledPlayers.push(data.callee_login);
                        loggedPlayers[data.callee_login].emit('incoming_challenge', {caller: data.caller_login});
                    }
                else 
                    socket.emit('callee_ingame', {callee: data.callee_login});
            else 
                socket.emit('callee_unavailable', {callee: data.callee_login});
        else 
            socket.emit('callee_same', {callee: data.callee_login});
    }

    private static function onAcceptChallenge(socket:SocketHandler, data)
    {
        if (loggedPlayers.exists(data.caller_login))
        {
            if (loggedPlayers[data.caller_login].calledPlayers.has(data.callee_login))
            {
                loggedPlayers[data.caller_login].calledPlayers = [];
                loggedPlayers[data.callee_login].calledPlayers = [];
                loggedPlayers[data.caller_login].ustate = InGame;
                loggedPlayers[data.callee_login].ustate = InGame;
                startGame(data.callee_login, data.caller_login);
            }
            else
                socket.emit('callout_not_found', {caller: data.caller_login});
        }
        else 
            socket.emit('caller_unavailable', {caller: data.caller_login});
    }

    private static function onCancelCallout(socket:SocketHandler, data)
    {
        if (loggedPlayers[data.caller_login].calledPlayers.has(data.callee_login))
            loggedPlayers[data.caller_login].calledPlayers.remove(data.callee_login);
        else
            socket.emit('callout_not_found', {callee: data.callee_login});
    }

    private static function startGame(login1:String, login2:String) 
    {
        var rand = Math.random();
        var whiteLogin = rand >= 0.5? login1 : login2;
        var blackLogin = rand >= 0.5? login2 : login1;

        var game:Game = new Game(whiteLogin, blackLogin);
        games[whiteLogin] = game;
        games[blackLogin] = game;

        loggedPlayers[whiteLogin].emit('game_started', {enemy: blackLogin, colour: 'white'});
        loggedPlayers[blackLogin].emit('game_started', {enemy: whiteLogin, colour: 'black'});
    }

    private static function onMove(socket:SocketHandler, data)
    {
        var game = games[data.issuer_login];
        if (data.issuer_login == game.whiteLogin)
            loggedPlayers[game.blackLogin].emit('move', mirrorMoveData(data));
        else 
        {
            data = mirrorMoveData(data);
            loggedPlayers[game.whiteLogin].emit('move', data);
        }

        var winner = game.move(data.fromI, data.fromJ, data.toI, data.toJ);
        if (winner != null)
            endGame(Mate, winner, game);
    }

    private static function handleDisconnectionForGame(disconnectedLogin:String)
    {
        if (!games.exists(disconnectedLogin))
            return;

        var game = games[disconnectedLogin];
        var winner = game.whiteLogin == disconnectedLogin? Black : White;
        endGame(Abandon, winner, game);
    }

    private static function endGame(reason:GameOverReason, winner:Null<Color>, game:Game) 
    {
        var matchResults = {winner_color: winner == null? "" : winner.getName().toLowerCase(), reason: reason.getName().toLowerCase()};

        for (login in [game.whiteLogin, game.blackLogin])
        {
            if (loggedPlayers.exists(login))
            {
                loggedPlayers[login].emit('game_ended', matchResults);
                loggedPlayers[login].ustate = MainMenu;
            }
            if (games.exists(login))
                games.remove(login);
        }

        game.log += winner == White? "w" : "b";
        Data.overwrite('games/${game.id}.txt', game.log);
    }

    private static function mirrorMoveData(data:MoveData):MoveData
    {
        var reflection = (i, j) -> (6 - (i % 2) - j);
        var newFromJ = reflection(data.fromI, data.fromJ);
        var newToJ = reflection(data.toI, data.toJ);
        return {issuer_login: data.issuer_login, fromI: data.fromI, toI: data.toI, fromJ: newFromJ, toJ: newToJ};
    }

}
