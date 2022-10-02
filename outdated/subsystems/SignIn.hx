package subsystems;

import Data.Playerdata;
import haxe.Json;
import sys.FileSystem;
import haxe.crypto.Md5;
using StringTools;

class SignIn 
{
    private static var loggedPlayers:Map<String, SocketHandler>;
    private static var games:Map<String, Game>; 
       
    private static var guestPasswords:Map<String, String> = [];
    
    public static function init(loggedPlayersMap:Map<String, SocketHandler>, gamesMap:Map<String, Game>) 
    {
        loggedPlayers = loggedPlayersMap;   
        games = gamesMap;
    }

    //------------------------------------------------------------------------------------------------------------

    public static function setGuestDetails(login:String, password:String) 
    {
        guestPasswords.set(login, password);
    }

    public static function eraseGuestDetails(login:String) 
    {
        guestPasswords.remove(login);
    }

    public static function attemptLogin(socket:SocketHandler, data) 
    {
        var guestLogin:Bool = StringTools.startsWith(data.login, "guest_");
        var playerdata:Playerdata;
        
        var passwordCorrect:Bool = false;
        if (guestLogin)
            passwordCorrect = guestPasswords.get(data.login) == data.password;
        else 
        {
            if (!Data.playerdataExists(data.login))
                return;

            playerdata = Data.getPlayerdata(data.login);
            passwordCorrect = playerdata.passwordMD5 == Md5.encode(data.password);
        }

        if (!passwordCorrect)
        {
            socket.emit('login_result', 'fail');
            return;
        }

        var otherSocket = loggedPlayers.get(data.login);
        if (otherSocket != null)
        {
            if (!guestLogin)
                Data.writeLog('logs/connection/', '${data.login} ALREADY ONLINE');
            otherSocket.emit("dont_reconnect", {});
            otherSocket.close();
        }

        if (guestLogin && !games.exists(data.login))
        {
            loggedPlayers.remove(data.login);
            guestPasswords.remove(data.login);
            socket.emit('login_result', 'fail');
            return;
        }

        onLogged(socket, data.login);
        if (guestLogin || games.exists(data.login))
            Connection.onPlayerReconnectedToGame(socket, games[data.login]);
        else 
            socket.emit('login_result', 'success');
    }

    public static function attemptRegister(socket:SocketHandler, data) 
    {
        if (!Data.playerdataExists(data.login))
        {
            register(socket, data.login, data.password);
            onLogged(socket, data.login);
            socket.emit('register_result', 'success');
        }
        else 
            socket.emit('register_result', 'fail');
    }

    private static function register(socket:SocketHandler, login:String, password:String)
    {
        var md5 = Md5.encode(password);

        var playerdata = {
            passwordMD5: md5,
            games: [],
            studies: [],
            puzzles: []
        };

        Data.writePlayerdata(login, playerdata);

        Data.writeLog('logs/connection/', '$login:${socket.id} /registered/');
    }

    private static function onLogged(socket:SocketHandler, login:String)
    {
        loggedPlayers[login] = socket;
        socket.login = login;
        socket.ustate = MainMenu;
        Data.writeLog('logs/connection/', '$login:${socket.id} /logged/');
    }
}