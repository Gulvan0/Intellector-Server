import haxe.crypto.Md5;
import js.Node;
import js.node.Path;
import js.node.Fs;
import js.node.Http;
import js.node.socketio.*;

class Main 
{

    public static var currID:Int;
    private static var passwords:Map<String, String> = [];
	private static var loggedPlayers:Map<String, Socket> = [];
	private static var games:Map<String, Game> = [];

	public static function main() 
	{
        currID = Std.parseInt(Fs.readFileSync(Path.join(Node.__dirname, "currid.txt"), {encoding: "UTF-8"}));
        init(Fs.readFileSync(Path.join(Node.__dirname, "playerdata.txt"), {encoding: "UTF-8"}));
    }

    public static function incrementID() 
    {
        currID++;
        Fs.writeFile(Path.join(Node.__dirname, "currid.txt"), '$currID', (e)->{});
    }

    private static function init(playerdata:String) 
    {
        trace(playerdata);
        for (line in playerdata.split('\n'))
        {
            var pair = line.split(':');
            passwords[pair[0]] = pair[1];
        }

        var server = new Server();

        server.on('connection', onConnected);
        server.on('disconnect', onDisconnected);

        server.listen(8000);
    }

    private static function onConnected(socket:Socket) 
    {
        socket.on('login', onLoginAttempt.bind(socket));
    }

    private static function onDisconnected(socket:Socket) 
    {
        for (k => v in loggedPlayers.keyValueIterator())
            if (v == socket)
            {
                loggedPlayers.remove(k);
                handleDisconnectionForGame(k);
                return;
            }
    }

    private static function onLoginAttempt(socket:Socket, data) 
    {
        if (passwords.get(data.login) == Md5.encode(data.password))
        {
            onLogged(socket, data.login);
            socket.emit('login_success');
        }
        else 
            socket.emit('login_failed');
    }

    private static function onLogged(socket:Socket, login:String)
    {
        loggedPlayers[login] = socket;
        socket.on('callout', onCallout.bind(socket));
    }

    private static function onCallout(socket:Socket, data)
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
            Fs.writeFile(Path.join(Node.__dirname, 'games/${game.id}.txt'), game.log, (e)->{});
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
        Fs.writeFile(Path.join(Node.__dirname, 'games/${game.id}.txt'), game.log, (e)->{});
    }

}
