import subsystems.*;
import sys.io.File;
import sys.ssl.Key;
import sys.ssl.Certificate;
import hx.ws.WebSocketSecureServer;
import SocketHandler.TimeControl;
import hx.ws.Log;
import hx.ws.WebSocketServer;
using Lambda;
using StringTools;

typedef Challenge = 
{
    var issuer:String;
    var timeControl:TimeControl;
}

class Main 
{
	private static var loggedPlayers:Map<String, SocketHandler> = [];
	private static var games:Map<String, Game> = [];
    private static var gamesByID:Map<Int, Game> = [];

	public static function main() 
	{    
        Proposals.init(loggedPlayers, games);
        SignIn.init(loggedPlayers, games);
        Spectation.init(loggedPlayers, games, gamesByID);
        Connection.init(loggedPlayers, games);
        GameManager.init(loggedPlayers, games, gamesByID);
        OpenChallengeManager.init(loggedPlayers, games);
        DirectChallengeManager.init(loggedPlayers, games);

        #if prod
        Log.mask = Log.INFO | Log.DEBUG;
        var cert = Certificate.loadFile("/etc/letsencrypt/live/play-intellector.ru/fullchain.pem");
        var key = Key.loadFile("/etc/letsencrypt/live/play-intellector.ru/privkey.pem");
        var hostname:String = '0.0.0.0';
        var server = new WebSocketSecureServer<SocketHandler>(hostname, 5000, cert, key, cert, 100);
        #else
        Log.mask = Log.INFO | Log.DEBUG | Log.DATA;
        var hostname:String = 'localhost';
        var server = new WebSocketServer<SocketHandler>(hostname, 5000, 100);
        #end

        server.start();
    }

    public static function handleEvent(sender:SocketHandler, eventName:String, data:Dynamic) 
    {
        switch eventName
        {
            case 'login':
                SignIn.attemptLogin(sender, data);
            case 'register':
                SignIn.attemptRegister(sender, data);
            case 'callout':
                DirectChallengeManager.createChallenge(sender, data);
            case 'accept_challenge':
                DirectChallengeManager.acceptChallenge(sender, data);
            case 'decline_challenge':
                DirectChallengeManager.declineChallenge(sender, data);
            case 'cancel_callout':
                DirectChallengeManager.cancelChallenge(sender, data);
            case 'move':
                GameManager.onMove(sender, data);
            case 'request_timeout_check':
                GameManager.onTimeoutCheck(sender, data);
            case 'message':
                GameManager.onMessage(sender, data);
            case 'get_game':
                onGameRequest(sender, data);
            case 'get_challenge':
                OpenChallengeManager.requestChallengeInfo(sender, data);
            case 'open_callout':
                OpenChallengeManager.createChallenge(sender, data);
            case 'accept_open_challenge':
                OpenChallengeManager.acceptChallenge(sender, data);
            case 'spectate':
                Spectation.spectate(sender, data);
            case 'stop_spectate':
                Spectation.stopSpectate(sender, data);
            case 'resign':
                GameManager.onResign(sender);
            case 'draw_offer':
                Proposals.offer(sender, Draw);
            case 'draw_cancel':
                Proposals.cancel(sender, Draw);
            case 'draw_accept':
                Proposals.accept(sender, Draw);
            case 'draw_decline':
                Proposals.decline(sender, Draw);
            case 'takeback_offer':
                Proposals.offer(sender, Takeback);
            case 'takeback_cancel':
                Proposals.cancel(sender, Takeback);
            case 'takeback_accept':
                Proposals.accept(sender, Takeback);
            case 'takeback_decline':
                Proposals.decline(sender, Takeback);
            default:
                trace("Unexpected event: " + eventName);
        }
    }

    private static function onGameRequest(socket:SocketHandler, data) 
    {
        var id = data.id;
        if (gamesByID.exists(id))
        {
            var game = gamesByID[id];
            if (game.hasPlayer(socket.login))
                Connection.onPlayerReconnectedToGame(socket, game);
            else 
                socket.emit('ongoing_game', game.getActualData('white'));
        }
        else if (Data.logExists(id))
            socket.emit('gamestate_over', {log: Data.getLog(id)});
        else 
            socket.emit('gamestate_notfound', {});
    }
}
