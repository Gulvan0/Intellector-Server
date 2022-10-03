package entities;

import services.ChallengeManager;
import services.Storage;
import haxe.Json;
import net.shared.ServerEvent;
import entities.util.UserState;
import net.SocketHandler;

class StoredUserData 
{
    private var login:String;
    private var pastGames:Array<Int>;
    private var studies:Array<Int>;
    private var ongoingCorrespondenceGames:Array<Int>;

    public function getPastGames():Array<Int>
    {
        return pastGames.copy();
    }

    public function getStudies():Array<Int>
    {
        return studies.copy();
    }

    public function getOngoingCorrespondenceGames():Array<Int>
    {
        return ongoingCorrespondenceGames.copy();
    }

    public function addPastGame(id:Int)
    {
        pastGames.push(id);
        Storage.savePlayerData(login, this);
    }

    public function addStudy(id:Int)
    {
        studies.push(id);
        Storage.savePlayerData(login, this);
    }

    public function addOngoingCorrespondenceGame(id:Int)
    {
        ongoingCorrespondenceGames.push(id);
        Storage.savePlayerData(login, this);
    }

    public function removeStudy(id:Int)
    {
        studies.remove(id);
        Storage.savePlayerData(login, this);
    }

    public function removeOngoingCorrespondenceGame(id:Int)
    {
        ongoingCorrespondenceGames.remove(id);
        Storage.savePlayerData(login, this);
    }

    public function new(login:String, ?pastGames:Array<Int>, ?studies:Array<Int>, ?ongoingCorrespondenceGames:Array<Int>) 
    {
        this.login = login;
        this.pastGames = pastGames != null? pastGames : [];
        this.studies = studies != null? studies : [];
        this.ongoingCorrespondenceGames = ongoingCorrespondenceGames != null? ongoingCorrespondenceGames : [];
    }
}

class User
{
    public var connection:SocketHandler;
    public var login:Null<String>;
    public var ongoingGame:Null<Int>;

    public var pendingOutgoingChallenges:Array<Int>;
    public var pendingIncomingChallenges:Array<Int>;

    public var storedData(default, null):StoredUserData;

    public var followerLogins:Array<String>;
    
    public function getState():UserState
    {
        if (login == null)
            return NotLogged;
        else if (ongoingGame == null)
            return Browsing;
        else
            return InGame;
    }

    public function emit(event:ServerEvent) 
    {
        connection.emit(event);
    }

    public function abortConnection(preventReconnection:Bool) 
    {
        if (preventReconnection)
            emit(DontReconnect);
        connection.close();
    }

    public function signIn(login:String) 
    {
        this.login = login;
        this.ongoingGame = Orchestrator.data.ongoingGamesByParticipantLogin.get(login).id;
        this.pendingIncomingChallenges = Orchestrator.data.pendingDirectChallengesByReceiverLogin.get(login).map(x -> x.id);
        this.pendingOutgoingChallenges = Orchestrator.data.pendingDirectChallengesByOwnerLogin.get(login).map(x -> x.id);
        
        this.storedData = Storage.loadPlayerData(login);
    }

    public function signOut() 
    {
        this.login = null;
        this.ongoingGame = null;
        this.pendingIncomingChallenges = null;
        this.pendingOutgoingChallenges = null;
        this.storedData = null;
    }

    public function new(connection:SocketHandler)
    {
        this.connection = connection;
    }
}