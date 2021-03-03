import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import hx.ws.Log;
import hx.ws.WebSocketServer;
import haxe.crypto.Md5;
import js.node.socketio.*;

typedef Event =
{
    var name:String;
    var data:Dynamic;
}

class Main 
{

    public static var currID:Int;
    private static var passwords:Map<String, String> = [];
	private static var loggedPlayers:Map<String, SocketHandler> = [];
	private static var games:Map<String, Game> = [];

    private static function path(s:String):String
    {
        var p = new Path(s);
        var progPath = Sys.programPath();
        p.dir = progPath.substring(0, progPath.lastIndexOf("\\"));
        return p.toString();
    }

	public static function main() 
	{    
        currID = Std.parseInt(File.getContent(path("currid.txt")));
        init(File.getContent(path("playerdata.txt")));
    }

    public static function incrementID() 
    {
        currID++;
        File.saveContent("currid.txt", '$currID');
    }

    private static function init(playerdata:String) 
    {
        for (line in playerdata.split('\n'))
        {
            var pair = line.split(':');
            passwords[pair[0]] = pair[1];
        }

        Log.mask = Log.INFO | Log.DEBUG | Log.DATA;
        var server = new WebSocketServer<SocketHandler>("localhost", 5000, 100);
        server.start();
    }

    public static function handleEvent(sender:SocketHandler, eventName:String, data:Dynamic) 
    {
        switch eventName
        {
            case 'login':
                onLoginAttempt(sender, data);
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
                //handleDisconnectionForGame(k);
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

    private static function onLogged(socket, login:String)
    {
        loggedPlayers[login] = socket;
        //socket.on('callout', onCallout.bind(socket));
    }

    /*private static function onCallout(socket, data)
    {
        if (loggedPlayers.exists(data.callee_login))
        {
            loggedPlayers[data.callee_login].emit('incoming_challenge', {caller: data.caller_login});
            loggedPlayers[data.callee_login].on('accept_challenge', startGame.bind(data.callee_login, data.caller_login));
        }
        else 
            socket.emit('callee_unavailable');
    }

    private static function startGame(login1:String, login2:String) 
    {
        var rand = Math.random();
        var whiteLogin = rand >= 0.5? login1 : login2;
        var blackLogin = rand >= 0.5? login2 : login1;

        var game:Game = new Game(whiteLogin, blackLogin);
        games[whiteLogin] = game;
        games[blackLogin] = game;

        loggedPlayers[whiteLogin].on('move', onMove.bind(whiteLogin));
        loggedPlayers[blackLogin].on('move', onMove.bind(blackLogin));

        loggedPlayers[whiteLogin].emit('game_started', {enemy: blackLogin, colour: 'white'});
        loggedPlayers[blackLogin].emit('game_started', {enemy: whiteLogin, colour: 'black'});
    }

    private static function onMove(issuerLogin:String, data)
    {
        var game = games[issuerLogin];
        var winner = game.move(data.fromI, data.fromJ, data.toI, data.toJ);
        if (issuerLogin == game.whiteLogin)
            loggedPlayers[game.blackLogin].emit('moved', data);
        else 
            loggedPlayers[game.whiteLogin].emit('moved', data);

        if (winner != null)
        {
            var winnerLogin = winner == White? game.whiteLogin : game.blackLogin;
            var loserLogin = winner == White? game.blackLogin : game.whiteLogin;
            loggedPlayers[winnerLogin].emit('win_normal');
            loggedPlayers[loserLogin].emit('loss_normal');
            games.remove(winnerLogin);
            games.remove(loserLogin);
            game.log += winner == White? "w" : "b";
            File.saveContent('games/${game.id}.txt', game.log);
        }
    }

    private static function handleDisconnectionForGame(disconnectedLogin:String)
    {
        if (!games.exists(disconnectedLogin))
            return;

        var game = games[disconnectedLogin];
        if (game.whiteLogin == disconnectedLogin)
        {
            game.log += "b";
            loggedPlayers[game.blackLogin].emit('win_quit');
            games.remove(game.blackLogin);
        }
        else 
        {
            game.log += "w";
            loggedPlayers[game.whiteLogin].emit('win_quit');
            games.remove(game.whiteLogin);
        }
        File.saveContent('games/${game.id}.txt', game.log);
    }*/

}
