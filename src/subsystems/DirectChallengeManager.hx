package subsystems;
import Game.Color;
import SocketHandler.CalloutParams;
import SocketHandler.TimeControl;
using Lambda;

class DirectChallengeManager 
{
    private static var loggedPlayers:Map<String, SocketHandler>;
    private static var games:Map<String, Game> = [];

    public static function init(loggedPlayersMap:Map<String, SocketHandler>, gamesMap:Map<String, Game>) 
    {
        loggedPlayers = loggedPlayersMap;   
        games = gamesMap;
    }
    
    public static function createChallenge(caller:SocketHandler, data)
    {
        var callee = loggedPlayers.get(data.callee_login);
        if (data.callee_login == data.caller_login)
            caller.emit('callee_same', {callee: data.callee_login});
        else if (callee == null)
            caller.emit('callee_unavailable', {callee: data.callee_login});
        else if (games.exists(data.callee_login))
            caller.emit('callee_ingame', {callee: data.callee_login});
        else if (caller.calledPlayers.has(data.callee_login))
            caller.emit('repeated_callout', {callee: data.callee_login});
        else
        {
            var callerColor = data.color == null? null : Color.createByName(data.color);
            caller.emit('callout_success', {callee: data.callee_login});
            caller.calledPlayers.push(data.callee_login);
            caller.calloutParams[data.callee_login] = {startSecs: data.secsStart, bonusSecs:data.secsBonus, color: callerColor};
            callee.emit('incoming_challenge', {caller: data.caller_login, startSecs: data.secsStart, bonusSecs:data.secsBonus, color: data.color});
        }
    }

    public static function acceptChallenge(callee:SocketHandler, data)
    {
        var caller = loggedPlayers.get(data.caller_login);
        if (caller == null)
            callee.emit('caller_unavailable', {caller: caller.login});
        else if (!caller.calledPlayers.has(callee.login))
            callee.emit('callout_not_found', {caller: caller.login});
        else
        {
            caller.calledPlayers = [];
            callee.calledPlayers = [];
            caller.ustate = InGame;
            callee.ustate = InGame;
            var params:CalloutParams = caller.calloutParams[callee.login];
            GameManager.startGame(callee.login, caller.login, params.startSecs, params.bonusSecs, params.color);
        }
    }

    public static function declineChallenge(callee:SocketHandler, data)
    {
        var caller = loggedPlayers.get(data.caller_login);
        if (caller == null)
            return;

        if (caller.calledPlayers.has(callee.login))
        {
            caller.calledPlayers.remove(callee.login);
            caller.calloutParams.remove(callee.login);
            caller.emit('challenge_declined', {callee: callee.login});
        }
    }

    public static function cancelChallenge(caller:SocketHandler, data)
    {
        if (caller.calledPlayers.has(data.callee_login))
        {
            caller.calledPlayers.remove(data.callee_login);
            caller.calloutParams.remove(data.callee_login);
        }
        else
            caller.emit('callout_not_found', {callee: data.callee_login});
    }
    
}