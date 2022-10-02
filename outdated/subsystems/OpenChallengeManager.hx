package subsystems;

import Game.Color;
import Main.Challenge;
using StringTools;

class OpenChallengeManager 
{
    private static var loggedPlayers:Map<String, SocketHandler>;
	private static var games:Map<String, Game> = [];

    public static function init(loggedPlayersMap:Map<String, SocketHandler>, gamesMap:Map<String, Game>) 
    {
        loggedPlayers = loggedPlayersMap;   
        games = gamesMap;
    }
    
    private static var openChallenges:Map<String, Challenge> = [];

    public static function removeChallenge(hostLogin:String) 
    {
        openChallenges.remove(hostLogin);
    }

    public static function requestChallengeInfo(socket:SocketHandler, data) 
    {
        var challenge = openChallenges.get(data.challenger);
        if (challenge != null)
        {
            var colorStr:String = challenge.color == null? null : challenge.color.getName();
            socket.emit('openchallenge_info', {challenger:challenge.issuer, startSecs:challenge.startSecs, bonusSecs:challenge.bonusSecs, color: colorStr});
        }
        else if (games.exists(data.challenger))
        {
            var game = games.get(data.challenger);
            if (socket.login == null)
                socket.emit('openchallenge_notfound', {});
            else if (games.get(socket.login) == game)
                Connection.onPlayerReconnectedToGame(socket, game, 'openchallenge_own_ongoing');
            else
                Spectation.spectate(socket, {watched_login: data.challenger});
        }
        else
            socket.emit('openchallenge_notfound', {});
    }

    public static function createChallenge(socket:SocketHandler, data) 
    {
        var callerColor:Null<Color> = data.color == null? null : Color.createByName(data.color);
        openChallenges[data.caller_login] = {issuer: data.caller_login, startSecs:data.startSecs, bonusSecs:data.bonusSecs, color: callerColor};
    }

    public static function acceptChallenge(socket:SocketHandler, data) 
    {
        var callee:String = data.callee_login;
        if (openChallenges.exists(data.caller_login) && loggedPlayers.exists(data.caller_login))
        {
            if (callee.startsWith("guest_"))
                if (loggedPlayers.exists(callee))
                {
                    socket.close();
                    return;
                }
                else
                {
                    var password:String = Utils.generateRandomPassword(10);
                    socket.login = callee;
                    loggedPlayers[callee] = socket;
                    SignIn.setGuestDetails(callee, password);
                    socket.emit("one_time_login_details", {password: password});
                }
            loggedPlayers[data.caller_login].calledPlayers = [];
            loggedPlayers[callee].calledPlayers = [];
            loggedPlayers[data.caller_login].ustate = InGame;
            loggedPlayers[callee].ustate = InGame;
            var params = openChallenges[data.caller_login];
            openChallenges.remove(data.caller_login);
            GameManager.startGame(callee, data.caller_login, params.startSecs, params.bonusSecs, params.color);
        }
        else 
            socket.emit('caller_unavailable', {caller: data.caller_login});
    }    

    public static function cancelChallenge(caller:SocketHandler, data)
    {
        openChallenges.remove(data.caller_login);
    }
}