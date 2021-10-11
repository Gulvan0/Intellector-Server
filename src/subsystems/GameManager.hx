package subsystems;

import Data.Playerdata;
import Game.Color;
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

        var winnerByResignationColor = game.whiteLogin == socket.login? Black : White;
        if (game.turn < 3)
            endGame(Abort, game);
        else 
            endGame(Resignation(winnerByResignationColor), game);
    }

    public static function onMessage(socket:SocketHandler, data) 
    {
        var game = games[data.issuer_login];
        if (game != null)
        {
            var issuerChar = game.whiteLogin == data.issuer_login? "w" : "b";
            game.log += '#C|$issuerChar/${data.message};\n';
    
            var opponent = loggedPlayers.get(game.getOpponent(data.issuer_login));
            if (opponent != null)
                opponent.emit('message', data);

            for (spec in game.whiteSpectators.concat(game.blackSpectators))
                if (spec != null)
                    spec.emit('message', data);
        }
        else
        {
            game = Spectation.getSpectatorsGame(data.issuer_login);
            if (game == null)
                return;

            for (spec in game.whiteSpectators.concat(game.blackSpectators))
                if (spec != null && spec.login != data.issuer_login)
                    spec.emit('spectator_message', data);
        }
    }

    public static function startGame(calleeLogin:String, callerLogin:String, startSecs:Int, bonusSecs:Int, callerColor:Null<Color>) 
    {
        var whiteLogin:String;
        var blackLogin:String;

        if (callerColor == null)
        {
            var rand = Math.random();
            whiteLogin = rand >= 0.5? callerLogin : calleeLogin;
            blackLogin = rand >= 0.5? calleeLogin : callerLogin;
        }
        else if (callerColor == White)
        {
            whiteLogin = callerLogin;
            blackLogin = calleeLogin;
        }
        else 
        {
            whiteLogin = calleeLogin;
            blackLogin = callerLogin;
        }

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

        var result:Null<MatchResult> = game.move(data.fromI, data.fromJ, data.toI, data.toJ, data.morphInto == null? null : FigureType.createByName(data.morphInto));

        var timedata = {whiteSeconds: game.secsLeftWhite, blackSeconds: game.secsLeftBlack};

        var whiteSocket = loggedPlayers.get(game.whiteLogin);
        var blackSocket = loggedPlayers.get(game.blackLogin);
        var spectators = game.whiteSpectators.concat(game.blackSpectators);

        for (spec in spectators)
            if (spec != null)
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

        for (spec in spectators)
            if (spec != null)
                spec.emit('move', data);

        if (result != null)
            endGame(result, game);
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
            case Mate(winner): winner == White? "w" : "b";
            case Breakthrough(winner): winner == White? "w" : "b";
            case Resignation(winner): winner == White? "w" : "b";
            case Timeout(winner): winner == White? "w" : "b";
            case Abandon(winner): winner == White? "w" : "b";
            default: "d";
        };
        var reasonStr = switch result 
        {
            case Mate(winner): "mat";
            case Breakthrough(winner): "bre";
            case Resignation(winner): "res";
            case Timeout(winner): "tim";
            case Abandon(winner): "aba";
            case ThreefoldRepetition: "rep";
            case HundredMoveRule: "100";
            case DrawAgreement: "agr";
            case Abort: "abo";
        };
        var resultsData = {winner_color: winnerStr, reason: result.getName().toLowerCase()};

        for (spec in game.whiteSpectators.concat(game.blackSpectators))
            if (spec != null)
                spec.emit('game_ended', resultsData);

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

        game.log += "#R|" + winnerStr + "/" + reasonStr;

        var addGameToHistory:Playerdata->Playerdata = pd -> {
            pd.games.push(game.id);
            return pd;
        };

        Data.writeGameLog(game.id, game.log);
        Data.editPlayerdata(game.whiteLogin, addGameToHistory);
        Data.editPlayerdata(game.blackLogin, addGameToHistory);
    }

}