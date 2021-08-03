package subsystems;

import Game.MatchResult;

typedef MoveData =
{
    var issuer_login:String;
    var fromI:Int;
    var toI:Int;
    var fromJ:Int;
    var toJ:Int;
    var morphInto:Null<String>;
}

class GameManager
{
    public static var currID(get, null):Int;
    private static var loggedPlayers:Map<String, SocketHandler>;
    private static var games:Map<String, Game>; 
    private static var gamesByID:Map<Int, Game>;

    public static function init(loggedPlayersMap:Map<String, SocketHandler>, gamesMap:Map<String, Game>, gamesByIDMap:Map<Int, Game>) 
    {
        currID = Std.parseInt(Data.read("currid.txt"));
        loggedPlayers = loggedPlayersMap;   
        games = gamesMap;
        gamesByID = gamesByIDMap;
    }

    public static function get_currID() 
    {
        currID++;
        Data.overwrite("currid.txt", '$currID');
        return currID;
    }

    //----------------------------------------------------------------------------------------------------------------------------------------

    public static function onResign(socket:SocketHandler) 
    {
        var game = games[socket.login];
        if (game == null)
            return;

        if (game.whiteLogin == socket.login)
            endGame(Resignation(Black), game);
        else 
            endGame(Resignation(White), game);
    }

    public static function onMessage(socket:SocketHandler, data) 
    {
        var game = games[data.issuer_login];
        if (game == null)
            return;

        var opponent = loggedPlayers.get(game.getOpponent(data.issuer_login));
        if (opponent != null)
            opponent.emit('message', data);
    }

    public static function startGame(login1:String, login2:String, startSecs:Int, bonusSecs:Int) 
    {
        var rand = Math.random();
        var whiteLogin = rand >= 0.5? login1 : login2;
        var blackLogin = rand >= 0.5? login2 : login1;

        var game:Game = new Game(whiteLogin, blackLogin, startSecs, bonusSecs);
        games[whiteLogin] = game;
        games[blackLogin] = game;
        gamesByID[game.id] = game;

        if (loggedPlayers.exists(whiteLogin))
            loggedPlayers[whiteLogin].emit('game_started', {enemy: blackLogin, colour: 'white', match_id: game.id, startSecs: startSecs, bonusSecs: bonusSecs});
        if (loggedPlayers.exists(blackLogin))
            loggedPlayers[blackLogin].emit('game_started', {enemy: whiteLogin, colour: 'black', match_id: game.id, startSecs: startSecs, bonusSecs: bonusSecs});
    }

    public static function onMove(socket:SocketHandler, data:MoveData)
    {
        var game = games.get(data.issuer_login);

        if (game == null)
            return;

        game.move(data.fromI, data.fromJ, data.toI, data.toJ, data.morphInto == null? null : FigureType.createByName(data.morphInto));

        var timedata = {whiteSeconds: game.secsLeftWhite, blackSeconds: game.secsLeftBlack};

        var whiteSocket = loggedPlayers.get(game.whiteLogin);
        var blackSocket = loggedPlayers.get(game.blackLogin);

        for (spec in game.whiteSpectators.concat(game.blackSpectators))
            spec.emit('time_correction', timedata);

        if (whiteSocket != null)
        {
            whiteSocket.emit('time_correction', timedata);
            if (data.issuer_login == game.blackLogin)
                whiteSocket.emit('move', data);
        }

        if (blackSocket != null)
        {
            blackSocket.emit('time_correction', timedata);
            if (data.issuer_login == game.whiteLogin)
                blackSocket.emit('move', data);
        }

        for (spec in game.whiteSpectators)
            spec.emit('move', data);
        for (spec in game.blackSpectators)
            spec.emit('move', data);
    }

    public static function onTimeoutCheck(socket:SocketHandler, data) 
    {
        var game = games.get(data.issuer_login);

        if (game != null)
            game.updateTimeLeft();
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
            games.remove(login);
            SignIn.eraseGuestDetails(login);
        }
        gamesByID.remove(game.id);

        game.log += winnerStr != ""? winnerStr : "draw";
        Data.overwrite('games/${game.id}.txt', game.log);
    }

}