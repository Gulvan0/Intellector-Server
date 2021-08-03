package subsystems;

class Spectation
{
    private static var loggedPlayers:Map<String, SocketHandler>;
    private static var games:Map<String, Game>; 
    private static var gamesByID:Map<Int, Game>;
       
    private static var spectators:Map<String, Int> = [];

    public static function init(loggedPlayersMap:Map<String, SocketHandler>, gamesMap:Map<String, Game>, gamesByIDMap:Map<Int, Game>) 
    {
        loggedPlayers = loggedPlayersMap;   
        games = gamesMap;
        gamesByID = gamesByIDMap;
    }

    public static function spectate(socket:SocketHandler, data) 
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

                for (playerLogin in [game.whiteLogin, game.blackLogin])
                {
                    var playerSocket = loggedPlayers.get(playerLogin);
                    if (playerSocket != null)
                        playerSocket.emit('new_spectator', {login: socket.login});
                }
            }
            else 
                socket.emit('watched_notingame', {watched_login: data.watched_login});
        else 
            socket.emit('watched_unavailable', {watched_login: data.watched_login});
    }

    public static function stopSpectate(socket:SocketHandler, ?data) 
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
}