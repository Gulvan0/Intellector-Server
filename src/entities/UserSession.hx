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

    private var skipDisconnectionProcessing:Bool = false; //If already processed or if aborted intentionally

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
        Logger.serviceLog("SESSION", 'Aborting connection for ${getInteractionReference()} (preventReconnection = $preventReconnection)');

        if (connection != null)
        {
            if (preventReconnection)
                emit(DontReconnect);
            skipDisconnectionProcessing = true;
            connection.close();
        }
    }

    public function onDisconnected()
    {
        Logger.serviceLog("SESSION", '${getInteractionReference()} disconnected (skipDisconnectionProcessing = $skipDisconnectionProcessing)');
        if (skipDisconnectionProcessing)
            return;

        skipDisconnectionProcessing = true;

        ChallengeManager.handleDisconnection(this);
        GameManager.handleDisconnection(this);

        var fiveMinutes:Int = 5 * 60 * 1000;
        reconnectionTimer = Timer.delay(onReconnectionTimeOut, fiveMinutes);
    }

    public function onReconnected(connection:SocketHandler):Array<ServerEvent>
    {
        Logger.serviceLog("SESSION", '${getInteractionReference()} reconnected');
        skipDisconnectionProcessing = false;

        if (reconnectionTimer != null)
            reconnectionTimer.stop();

        this.reconnectionTimer = null;
        this.connection = connection;

        GameManager.handleReconnection(this);

        var returnedEvents = missedEvents;
        missedEvents = [];
        return returnedEvents;
    }

    private function onReconnectionTimeOut() 
    {
        Logger.serviceLog("SESSION", '${getInteractionReference()} failed to reconnect in time, the session is to be destroyed');
        reconnectionTimer = null;
        Auth.detachSession(reconnectionToken);

        GameManager.handleSessionDestruction(this);
        LoginManager.handleSessionDestruction(this);
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