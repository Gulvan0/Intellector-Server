package subsystems;

import Main.Challenge;
using Lambda;

class Connection
{
    private static var loggedPlayers:Map<String, SocketHandler>;
    private static var games:Map<String, Game>; 

    public static function init(loggedPlayersMap:Map<String, SocketHandler>, gamesMap:Map<String, Game>) 
    {
        loggedPlayers = loggedPlayersMap;   
        games = gamesMap;
    }

    public static function handleDisconnect(socket:SocketHandler) 
    {
        loggedPlayers.remove(socket.login);
        Spectation.stopSpectate(socket);
        OpenChallengeManager.removeChallenge(socket.login);
        
        var playersLeft:String = loggedPlayers.empty()? 'none' : [for (k in loggedPlayers.keys()) k].join(", ");
        Data.writeLog('logs/connection/', '${socket.login} removed. Online: $playersLeft');
        handleDisconnectionForGame(socket.login);
    }

    private static function handleDisconnectionForGame(disconnectedLogin:String)
    {
        if (!games.exists(disconnectedLogin))
            return;

        var game = games[disconnectedLogin];
        var opponent = game.whiteLogin == disconnectedLogin? game.blackLogin : game.whiteLogin;
        var disconnectedLetter = game.whiteLogin == disconnectedLogin? "w" : "b";

        game.log += '#E|dcn/$disconnectedLetter\n';

        if (!loggedPlayers.exists(opponent))
            game.launchTerminateTimer();
        else 
            loggedPlayers.get(opponent).emit("opponent_disconnected", {});
    }

    public static function onPlayerReconnectedToGame(socket:SocketHandler, game:Game, ?eventName:String = 'ongoing_game') 
    {
        socket.ustate = InGame;
        socket.emit(eventName, game.getActualData('white'));

        var reconnectedLetter = game.whiteLogin == socket.login? "w" : "b";
        game.log += '#E|rcn/$reconnectedLetter\n';
                
        var opponent:String = game.getOpponent(socket.login);
        if (loggedPlayers.exists(opponent))
            loggedPlayers.get(opponent).emit("opponent_reconnected", {});

        for (type => offerer in game.pendingOfferer)
            if (offerer == opponent)
                socket.emit(Proposals.eventName(type, Offer), {});
    }
}