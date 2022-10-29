package entities;

import net.shared.GameInfo;
import net.shared.ClientEvent;
import services.Logger;
import services.Auth;
import services.LoginManager;
import services.GameManager;
import stored.PlayerData;
import haxe.Timer;
import services.ChallengeManager;
import services.Storage;
import haxe.Json;
import net.shared.ServerEvent;
import entities.util.UserState;
import net.SocketHandler;

class UserSession
{
    public var connection:Null<SocketHandler>;
    public var login:Null<String>;

    public var storedData(default, null):PlayerData;

    public var reconnectionToken(default, null):String;
    private var reconnectionTimer:Timer;
    private var missedEvents:Array<ServerEvent>;

    public var ongoingFiniteGameID(get, set):Null<Int>;
    public var viewedGameID:Null<Int>;

    private function get_ongoingFiniteGameID():Null<Int>
    {
        return storedData.getOngoingFiniteGame();
    }

    private function set_ongoingFiniteGameID(id:Null<Int>):Null<Int>
    {
        if (id == null)
            storedData.removeOngoingFiniteGame();
        else
            storedData.addOngoingFiniteGame(id);
        return id;
    }

    public function getState():UserState
    {
        if (connection == null)
            return AwaitingReconnection;
        else if (login == null)
            return NotLogged;
        else if (ongoingFiniteGameID != null)
            return PlayingFiniteGame(ongoingFiniteGameID);
        else if (viewedGameID != null)
            return ViewingGame(viewedGameID);
        else
            return Browsing;
    }

    public function getRelevantGameIDs():Array<Int> 
    {
        var ids = storedData.getOngoingGameIDs();
        if (ongoingFiniteGameID == null && viewedGameID != null)
            ids.push(viewedGameID);
        return ids;
    }

    public function getLogReference():String
    {
        if (connection == null)
            return 'TokenHolder($reconnectionToken)';
        else if (login == null)
            return 'Connection(${connection.id})';
        else
            return 'Player($login, ${connection.id})';
    }

    public function getInteractionReference():String 
    {
        if (login == null)
            return reconnectionToken;
        else
            return login;
    }

    public function emit(event:ServerEvent) 
    {
        if (connection != null)
            connection.emit(event);
        else
            missedEvents.push(event);
    }

    public function abortConnection(preventReconnection:Bool) 
    {
        if (connection != null)
        {
            if (preventReconnection)
                emit(DontReconnect);
            connection.close(); //TODO: Don't perform extra actions in this case
        }
    }

    public function onDisconnected()
    {
        ChallengeManager.handleDisconnection(this);
        GameManager.handleDisconnection(this);
        LoginManager.handleDisconnection(this);
        //TODO: other managers should handle that too
        //TODO: Stop spectating or following

        var fiveMinutes:Int = 5 * 60 * 1000;
        reconnectionTimer = Timer.delay(onReconnectionTimeOut, fiveMinutes);
    }

    public function onReconnected(connection:SocketHandler):Array<ServerEvent>
    {
        if (reconnectionTimer != null)
            reconnectionTimer.stop();

        this.reconnectionTimer = null;
        this.connection = connection;

        LoginManager.handleReconnection(this);
        //TODO: handleReconnection (for all other relevant managers)

        var returnedEvents = missedEvents;
        missedEvents = [];

        return returnedEvents;
    }

    private function onReconnectionTimeOut() 
    {
        //TODO: Ask managers to execute handleSessionDestruction
        reconnectionTimer = null;
        Auth.detachSession(reconnectionToken);
    }

    public function isGuest():Bool
    {
        return Auth.isGuest(getInteractionReference());    
    }

    public function onLoggedIn(login:String) 
    {
        this.login = login;
        this.storedData = Storage.loadPlayerData(login);
    }

    public function onLoggedOut() 
    {
        this.login = null;
        this.storedData = null;
    }

    public function new(connection:SocketHandler, token:String)
    {
        this.connection = connection;
        this.reconnectionToken = token;
        
        emit(SessionToken(token));
    }
}