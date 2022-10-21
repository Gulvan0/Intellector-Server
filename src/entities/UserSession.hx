package entities;

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
    
    public function getState():UserState
    {
        if (connection == null)
            return AwaitingReconnection;
        else if (login == null)
            return NotLogged;
        else if (GameManager.getOngoingGameByParticipantLogin(login) == null)
            return Browsing;
        else
            return InGame;
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

    public function onReconnected(connection:SocketHandler)
    {
        if (reconnectionTimer != null)
            reconnectionTimer.stop();

        this.reconnectionTimer = null;
        this.connection = connection;

        LoginManager.handleReconnection(this);
        //TODO: handleReconnection (for all other relevant managers)

        var missedEvent:Null<ServerEvent> = missedEvents.shift();
        while (missedEvent != null)
        {
            emit(missedEvent);
            missedEvent = missedEvents.shift();
        }
    }

    private function onReconnectionTimeOut() 
    {
        //TODO: Ask managers to execute handleSessionDestruction
        reconnectionTimer = null;
        Auth.detachSession(reconnectionToken);
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