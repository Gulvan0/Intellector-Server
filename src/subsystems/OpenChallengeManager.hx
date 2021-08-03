package subsystems;

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

    public static function createChallenge(socket:SocketHandler, data) 
    {
        openChallenges[data.caller_login] = {issuer: data.caller_login, timeControl: {startSecs:data.startSecs, bonusSecs:data.bonusSecs}};
    }

    public static function acceptChallenge(socket:SocketHandler, data) 
    {
        var callee:String = data.callee_login;
        if (loggedPlayers.exists(data.caller_login))
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
            var tc = openChallenges[data.caller_login].timeControl;
            openChallenges.remove(data.caller_login);
            GameManager.startGame(callee, data.caller_login, tc.startSecs, tc.bonusSecs);
        }
        else 
            socket.emit('caller_unavailable', {caller: data.caller_login});
    }    
}