package entities;

import net.shared.ServerMessage;
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
import net.SocketHandler;

class UserSession
{
    public var connection:Null<SocketHandler>;
    public var login:Null<String>;

    public var storedData(default, null):PlayerData;

    public var sessionID(default, null):Int;
    private var reconnectionTimer:Timer;

    private var sentEvents:Map<Int, ServerEvent> = [];
    public var lastSentServerEventID(default, null):Int = 0;
    public var lastProcessedClientEventID:Int = 0;
    public var lastReceivedClientEventID:Int = 0;

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
        var msg:ServerMessage;

        switch event 
        {
            case DontReconnect | KeepAliveBeat | ResendRequest(_, _) | MissedEvents(_) | GreetingResponse(_):
                msg = new ServerMessage(-1, event);
            default:
                lastSentServerEventID++;
                sentEvents.set(lastSentServerEventID, event);
                msg = new ServerMessage(lastSentServerEventID, event);
        }

        if (connection != null)
            connection.emit(msg);
    }

    public function resendMessages(from:Int, to:Int) 
    {
        var map:Map<Int, ServerEvent> = [];

        for (i in from...(to+1))
            map.set(i, sentEvents.get(i));

        emit(MissedEvents(map));
    }

    public function abortConnection(preventReconnection:Bool) 
    {
        Logger.serviceLog("SESSION", 'Aborting connection for $this (preventReconnection = $preventReconnection)');

        if (reconnectionTimer != null)
            reconnectionTimer.stop();

        reconnectionTimer = null;

        Auth.detachSession(sessionID);

        GameManager.handleDisconnection(this);

        ChallengeManager.handleSessionDestruction(this);
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

        GameManager.handleDisconnection(this);

        var fiveMinutes:Int = 1 * 60 * 1000; //TODO: Revert to five minutes after testing
        reconnectionTimer = Timer.delay(onReconnectionTimeOut, fiveMinutes);
    }

    public function onReconnected(connection:SocketHandler, lastProcessedMessageID:Int):Map<Int, ServerEvent>
    {
        Logger.serviceLog("SESSION", '$this reconnected');
        skipDisconnectionProcessing = false;

        if (reconnectionTimer != null)
            reconnectionTimer.stop();

        this.reconnectionTimer = null;
        this.connection = connection;

        GameManager.handleReconnection(this);

        var nextEventID:Int = lastProcessedMessageID + 1;
        var missedEvents:Map<Int, ServerEvent> = [];

        while (sentEvents.exists(nextEventID))
        {
            missedEvents.set(nextEventID, sentEvents.get(nextEventID));
            nextEventID++;
        }

        return missedEvents;
    }

    private function onReconnectionTimeOut() 
    {
        Logger.serviceLog("SESSION", '$this failed to reconnect in time, the session is to be destroyed');
        reconnectionTimer = null;
        Auth.detachSession(sessionID);

        ChallengeManager.handleSessionDestruction(this);
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