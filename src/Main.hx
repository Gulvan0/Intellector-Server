import sys.io.File;
import sys.ssl.Key;
import sys.ssl.Certificate;
import hx.ws.WebSocketSecureServer;
import Game.MatchResult;
import SocketHandler.TimeControl;
import Game.FigureType;
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

typedef MoveData =
{
    var issuer_login:String;
    var fromI:Int;
    var toI:Int;
    var fromJ:Int;
    var toJ:Int;
    var morphInto:Null<String>;
}

typedef Challenge = 
{
    var issuer:String;
    var timeControl:TimeControl;
}

class Main 
{

    public static var currID(get, null):Int;
    private static var passwords:Map<String, String> = [];
	private static var loggedPlayers:Map<String, SocketHandler> = [];
	private static var games:Map<String, Game> = [];
    private static var gamesByID:Map<Int, Game> = [];
    private static var spectators:Map<String, Int> = [];
    private static var openChallenges:Map<String, Challenge> = [];

	public static function main() 
	{    
        currID = Std.parseInt(Data.read("currid.txt"));
        parsePasswords(Data.read("playerdata.txt"));

        #if prod
        Log.mask = Log.INFO | Log.DEBUG;
        var cert = Certificate.loadFile("/root/15646055_www.example.com.cert");
        var key = Key.loadFile("/root/15646055_www.example.com.key");
        var hostname:String = '0.0.0.0';
        var server = new WebSocketSecureServer<SocketHandler>(hostname, 5000, cert, key, cert, 100);
        #else
        Log.mask = Log.INFO | Log.DEBUG | Log.DATA;
        var hostname:String = 'localhost';
        var server = new WebSocketServer<SocketHandler>(hostname, 5000, 100);
        #end

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
            case 'decline_challenge':
                onDeclineChallenge(sender, data);
            case 'cancel_callout':
                onCancelCallout(sender, data);
            case 'move':
                onMove(sender, data);
            case 'request_timeout_check':
                onTimeoutCheck(sender, data);
            case 'message':
                onMessage(sender, data);
            case 'get_game':
                onGameRequest(sender, data);
            case 'get_challenge':
                onOpenChallengeRequest(sender, data);
            case 'open_callout':
                onOpenCallout(sender, data);
            case 'accept_open_challenge':
                onOpenChallengeAccept(sender, data);
            case 'spectate':
                onSpectate(sender, data);
            case 'stop_spectate':
                onStopSpectate(sender, data);
            case 'resign':
                onResign(sender);
            default:
                trace("Unexpected event: " + eventName);
        }
    }

    public static function handleDisconnect(socket:SocketHandler) 
    {
        loggedPlayers.remove(socket.login);
        spectators.remove(socket.login);
        openChallenges.remove(socket.login);
        
        var playersLeft:String = loggedPlayers.empty()? 'none' : [for (k in loggedPlayers.keys()) k].join(", ");
        Data.writeLog('logs/connection/', '${socket.login} removed. Online: $playersLeft');
        handleDisconnectionForGame(socket.login);
    }

    private static function onSpectate(socket:SocketHandler, data) 
    {
        if (loggedPlayers.exists(data.watched_login))
            if (games.exists(data.watched_login))
            {
                var game = games.get(data.watched_login);
                var color = data.watched_login == game.whiteLogin? 'white' : 'black';

                spectators.set(socket.login, game.id);

                socket.emit('spectation_data', game.getActualData(color));

                if (color == 'white')
                    game.whiteSpectators.push(socket);
                else 
                    game.blackSpectators.push(socket);

                loggedPlayers[game.whiteLogin].emit('new_spectator', {login: socket.login});
                loggedPlayers[game.blackLogin].emit('new_spectator', {login: socket.login});
            }
            else 
                socket.emit('watched_notingame', {watched_login: data.watched_login});
        else 
            socket.emit('watched_unavailable', {watched_login: data.watched_login});
    }

    private static function onStopSpectate(socket:SocketHandler, data) 
    {
        var gameID = spectators.get(socket.login);
        if (gameID != null)
        {
            var game = gamesByID[gameID];

            if (game != null)
            {
                game.whiteSpectators.remove(socket);
                game.blackSpectators.remove(socket);
                
                if (loggedPlayers.exists(game.whiteLogin))
                    loggedPlayers[game.whiteLogin].emit('spectator_left', {login: socket.login});
                if (loggedPlayers.exists(game.blackLogin))
                loggedPlayers[game.blackLogin].emit('spectator_left', {login: socket.login});
            }

            spectators.remove(socket.login);
        }
    }

    private static function onGameRequest(socket:SocketHandler, data) 
    {
        var id = data.id;
        if (gamesByID.exists(id))
        {
            var game = gamesByID[id];
            if (games.get(socket.login) == game)
                socket.ustate = InGame;
            socket.emit('gamestate_ongoing', game.getActualData('white'));
        }
        else if (Data.logExists(id))
            socket.emit('gamestate_over', {log: Data.getLog(id)});
        else 
            socket.emit('gamestate_notfound', {});
    }

    private static function onOpenChallengeRequest(socket:SocketHandler, data) 
    {
        var challenge = openChallenges.get(data.challenger);
        if (challenge != null)
            socket.emit('openchallenge_info', {challenger:challenge.issuer, startSecs:challenge.timeControl.startSecs, bonusSecs:challenge.timeControl.bonusSecs});
        else if (games.exists(data.challenger))
        {
            var game = games.get(data.challenger);
            if (games.get(socket.login) == game)
                socket.ustate = InGame;
            socket.emit('openchallenge_ongoing', game.getActualData('white'));
        }
        else
            socket.emit('openchallenge_notfound', {});
    }

    private static function onOpenCallout(socket:SocketHandler, data) 
    {
        openChallenges[data.caller_login] = {issuer: data.caller_login, timeControl: {startSecs:data.startSecs, bonusSecs:data.bonusSecs}};
    }

    private static function onOpenChallengeAccept(socket:SocketHandler, data) 
    {
        var callee:String = data.callee_login;
        if (loggedPlayers.exists(data.caller_login))
        {
            if (callee.startsWith("guest_"))
                loggedPlayers[callee] = socket;
            loggedPlayers[data.caller_login].calledPlayers = [];
            loggedPlayers[callee].calledPlayers = [];
            loggedPlayers[data.caller_login].ustate = InGame;
            loggedPlayers[callee].ustate = InGame;
            var tc = openChallenges[data.caller_login].timeControl;
            openChallenges.remove(data.caller_login);
            startGame(callee, data.caller_login, tc.startSecs, tc.bonusSecs);
        }
        else 
            socket.emit('caller_unavailable', {caller: data.caller_login});
    }

    private static function onResign(socket:SocketHandler) 
    {
        var game = games[socket.login];
        if (game == null)
            return;

        if (game.whiteLogin == socket.login)
            endGame(Resignation(Black), game);
        else 
            endGame(Resignation(White), game);
    }

    private static function onMessage(socket:SocketHandler, data) 
    {
        if (games[data.issuer_login].whiteLogin == data.issuer_login)
            loggedPlayers[games[data.issuer_login].blackLogin].emit('message', data);
        else 
            loggedPlayers[games[data.issuer_login].whiteLogin].emit('message', data);
    }

    private static function onLoginAttempt(socket:SocketHandler, data) 
    {
        if (!loggedPlayers.exists(data.login))
            if (passwords.get(data.login) == Md5.encode(data.password))
            {
                onLogged(socket, data.login);
                socket.emit('login_result', 'success');
            }
            else 
                socket.emit('login_result', 'fail');
        else
        {
            Data.writeLog('logs/connection/', '${data.login} ALREADY ONLINE');
            socket.emit('login_result', 'online');
        }
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
        socket.login = login;
        socket.ustate = MainMenu;
        Data.writeLog('logs/connection/', '$login:${socket.id} /logged/');
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
                        socket.emit('callout_success', {callee: data.callee_login});
                        loggedPlayers[data.caller_login].calledPlayers.push(data.callee_login);
                        loggedPlayers[data.caller_login].calloutTimeControls[data.callee_login] = {startSecs: data.secsStart, bonusSecs:data.secsBonus};
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
                var tc = loggedPlayers[data.caller_login].calloutTimeControls[data.callee_login];
                startGame(data.callee_login, data.caller_login, tc.startSecs, tc.bonusSecs);
            }
            else
                socket.emit('callout_not_found', {caller: data.caller_login});
        }
        else 
            socket.emit('caller_unavailable', {caller: data.caller_login});
    }

    private static function onDeclineChallenge(socket:SocketHandler, data)
    {
        if (!loggedPlayers.exists(data.caller_login))
            return;

        if (loggedPlayers[data.caller_login].calledPlayers.has(data.callee_login))
        {
            loggedPlayers[data.caller_login].calledPlayers.remove(data.callee_login);
            loggedPlayers[data.caller_login].emit('challenge_declined', {callee: data.callee_login});
        }
    }

    private static function onCancelCallout(socket:SocketHandler, data)
    {
        if (loggedPlayers[data.caller_login].calledPlayers.has(data.callee_login))
            loggedPlayers[data.caller_login].calledPlayers.remove(data.callee_login);
        else
            socket.emit('callout_not_found', {callee: data.callee_login});
    }

    private static function startGame(login1:String, login2:String, startSecs:Int, bonusSecs:Int) 
    {
        var rand = Math.random();
        var whiteLogin = rand >= 0.5? login1 : login2;
        var blackLogin = rand >= 0.5? login2 : login1;

        var game:Game = new Game(whiteLogin, blackLogin, startSecs, bonusSecs);
        games[whiteLogin] = game;
        games[blackLogin] = game;
        gamesByID[game.id] = game;

        loggedPlayers[whiteLogin].emit('game_started', {enemy: blackLogin, colour: 'white', match_id: game.id, startSecs: startSecs, bonusSecs: bonusSecs});
        loggedPlayers[blackLogin].emit('game_started', {enemy: whiteLogin, colour: 'black', match_id: game.id, startSecs: startSecs, bonusSecs: bonusSecs});
    }

    private static function onMove(socket:SocketHandler, data)
    {
        var game = games.get(data.issuer_login);

        if (game == null)
            return;

        game.move(data.fromI, data.fromJ, data.toI, data.toJ, data.morphInto == null? null : FigureType.createByName(data.morphInto));

        var timedata = {whiteSeconds: game.secsLeftWhite, blackSeconds: game.secsLeftBlack};

        loggedPlayers[game.whiteLogin].emit('time_correction', timedata);
        loggedPlayers[game.blackLogin].emit('time_correction', timedata);
        for (spec in game.whiteSpectators.concat(game.blackSpectators))
            spec.emit('time_correction', timedata);

        if (data.issuer_login == game.whiteLogin)
            loggedPlayers[game.blackLogin].emit('move', data);
        else 
            loggedPlayers[game.whiteLogin].emit('move', data);

        for (spec in game.whiteSpectators)
            spec.emit('move', data);
        for (spec in game.blackSpectators)
            spec.emit('move', data);
    }

    private static function onTimeoutCheck(socket:SocketHandler, data) 
    {
        var game = games.get(data.issuer_login);

        if (game != null)
            game.updateTimeLeft();
    }

    private static function handleDisconnectionForGame(disconnectedLogin:String)
    {
        if (!games.exists(disconnectedLogin))
            return;

        var game = games[disconnectedLogin];
        var opponentColor = game.whiteLogin == disconnectedLogin? Black : White;
        var opponent = game.whiteLogin == disconnectedLogin? game.blackLogin : game.whiteLogin;
        if (disconnectedLogin.startsWith("guest"))
            endGame(Abandon(opponentColor), game);
        else if (!loggedPlayers.exists(opponent))
            game.launchTerminateTimer();
        //else send disconnect notification
    }

    public static function endGame(result:MatchResult, game:Game) 
    {
        var winnerStr = switch result 
        {
            case Mate(winner): winner.getName().toLowerCase();
            case Breakthrough(winner): winner.getName().toLowerCase();
            case Resignation(winner): winner.getName().toLowerCase();
            case Timeout(winner): winner.getName().toLowerCase();
            case Abandon(winner): winner.getName().toLowerCase();
            default: "";
        }
        var resultsData = {winner_color: winnerStr, reason: result.getName().toLowerCase()};

        for (login in [game.whiteLogin, game.blackLogin])
        {
            if (loggedPlayers.exists(login))
            {
                loggedPlayers[login].emit('game_ended', resultsData);
                loggedPlayers[login].ustate = MainMenu;
            }
            if (games.exists(login))
                games.remove(login);
        }
        gamesByID.remove(game.id);

        game.log += winnerStr != ""? winnerStr : "draw";
        Data.overwrite('games/${game.id}.txt', game.log);
    }

}
