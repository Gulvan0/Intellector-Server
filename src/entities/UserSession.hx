package entities;

import services.PageManager;
import services.SpecialBroadcaster;
import net.shared.dataobj.GameInfo;
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

    public var sessionID(default, null):Int;
    private var reconnectionTimer:Timer;
    private var missedEvents:Array<ServerEvent> = [];

    @:isVar public var ongoingFiniteGameID(get, set):Null<Int>;
    public var viewedGameID(get, never):Null<Int>;

    private var skipDisconnectionProcessing:Bool = false; //If already processed or if aborted intentionally

    private function get_ongoingFiniteGameID():Null<Int>
    {
        return ongoingFiniteGameID;
    }

    private function get_viewedGameID():Null<Int>
    {
        return switch PageManager.getPage(this) 
        {
            case Game(id): id;
            default: null;
        }
    }

    private function set_ongoingFiniteGameID(id:Null<Int>):Null<Int>
    {
        if (storedData != null)
            if (id == null)
                storedData.removeOngoingFiniteGame();
            else
                storedData.addOngoingFiniteGame(id);

        return ongoingFiniteGameID = id;
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
        var ids:Array<Int> = [];

        if (storedData != null)
            ids = storedData.getOngoingGameIDs();
        else if (ongoingFiniteGameID != null)
            ids = [ongoingFiniteGameID];
        
        if (ongoingFiniteGameID == null && viewedGameID != null)
            ids.push(viewedGameID);

        return ids;
    }

    public function getReference():String 
    {
        if (login == null)
            return '_$sessionID';
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
        Logger.serviceLog("SESSION", 'Aborting connection for $this (preventReconnection = $preventReconnection)');

        if (reconnectionTimer != null)
            reconnectionTimer.stop();

        reconnectionTimer = null;

        Auth.detachSession(sessionID);

        ChallengeManager.handleDisconnection(this);
        GameManager.handleDisconnection(this);

        GameManager.handleSessionDestruction(this);
        LoginManager.handleSessionDestruction(this);
        SpecialBroadcaster.handleSessionDestruction(this);

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
        Logger.serviceLog("SESSION", '$this disconnected (skipDisconnectionProcessing = $skipDisconnectionProcessing)');

        if (skipDisconnectionProcessing)
            return;

        skipDisconnectionProcessing = true;

        this.connection = null;

        ChallengeManager.handleDisconnection(this);
        GameManager.handleDisconnection(this);

        var fiveMinutes:Int = 1 * 60 * 1000; //TODO: Revert to five minutes after testing
        reconnectionTimer = Timer.delay(onReconnectionTimeOut, fiveMinutes);
    }

    public function onReconnected(connection:SocketHandler):Array<ServerEvent>
    {
        Logger.serviceLog("SESSION", '$this reconnected');
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
        Logger.serviceLog("SESSION", '$this failed to reconnect in time, the session is to be destroyed');
        reconnectionTimer = null;
        Auth.detachSession(sessionID);

        GameManager.handleSessionDestruction(this);
        LoginManager.handleSessionDestruction(this);
        SpecialBroadcaster.handleSessionDestruction(this);
        PageManager.handleSessionDestruction(this);
    }

    public function isGuest():Bool
    {
        return Auth.isGuest(getReference());    
    }

    public function onLoggedIn(login:String) 
    {
        this.login = login;
        this.storedData = Storage.loadPlayerData(login);
        this.ongoingFiniteGameID = storedData.getOngoingFiniteGame();
    }

    public function onLoggedOut() 
    {
        this.login = null;
        this.storedData = null;
        this.ongoingFiniteGameID = null;
    }

    public inline function toString():String
    {
        return getReference();    
    }

    public function new(connection:SocketHandler, sessionID:Int)
    {
        this.connection = connection;
        this.sessionID = sessionID;
    }
}