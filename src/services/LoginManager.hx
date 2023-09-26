package services;

import net.shared.dataobj.OngoingGameInfo;
import net.shared.dataobj.ChallengeData;
import entities.FiniteTimeGame;
import entities.UserSession;

class LoginManager 
{
    private static var loggedUserByLogin:Map<String, UserSession> = [];

    public static function getUser(login:String):Null<UserSession>
    {
        return loggedUserByLogin.get(login);
    }

    public static function getLoggedUsers():Array<UserSession>
    {
        return Lambda.array(loggedUserByLogin);
    }

    public static function login(user:UserSession, login:String, password:String, ?asGreeting:Bool = false) 
    {
        Logger.serviceLog('LOGIN', '$user attempts logging in as $login');
        if (!Auth.userExists(login))
        {
            Logger.serviceLog('LOGIN', 'Failed to log $user in as $login: user does not exist');
            if (asGreeting)
                user.emit(GreetingResponse(ConnectedAsGuest(user.sessionID, Auth.getTokenBySessionID(user.sessionID), true, Shutdown.isStopping())));
            else
                user.emit(LoginResult(Fail));
        }
        else if (!Auth.isValid(login, password))
        {
            Logger.serviceLog('LOGIN', 'Failed to log $user in as $login: invalid password');
            if (asGreeting)
                user.emit(GreetingResponse(ConnectedAsGuest(user.sessionID, Auth.getTokenBySessionID(user.sessionID), true, Shutdown.isStopping())));
            else
                user.emit(LoginResult(Fail));
        }
        else
        {
            var alreadyExistingSession:Null<UserSession> = loggedUserByLogin.get(login);
            if (alreadyExistingSession != null)
            {
                var lastMessageTS:Float = loggedUserByLogin[login].storedData.getLastMessageTimestamp().getTime();
                var intervalSeconds:Float = Sys.time() - lastMessageTS / 1000;

                if (!asGreeting || intervalSeconds > 60 * 60)
                {
                    Logger.serviceLog('LOGIN', 'A session for player $login already exists (last message $intervalSeconds secs ago), aborting the connection and destroying');
                    alreadyExistingSession.abortConnection(true);
                }
                else if (alreadyExistingSession.connection == null)
                {
                    Logger.serviceLog('LOGIN', 'A session for player $login already exists, but not connected (last message $intervalSeconds secs ago), aborting the connection and destroying');
                    alreadyExistingSession.abortConnection(true);
                }
                else
                {
                    Logger.serviceLog('LOGIN', 'A session for player $login already exists (last message $intervalSeconds secs ago), refusing to log other session in');
                    user.emit(GreetingResponse(ConnectedAsGuest(user.sessionID, Auth.getTokenBySessionID(user.sessionID), false, Shutdown.isStopping())));
                    return;
                }
            }

            loggedUserByLogin.set(login, user);
            user.onLoggedIn(login);

            var relevantChallenges:Array<ChallengeData> = ChallengeManager.getAllChallengesByPlayerLogin(login);
            var finiteGameID:Null<Int> = user.ongoingFiniteGameID;

            if (finiteGameID == null)
            {
                Logger.serviceLog('LOGIN', 'Login successful for $login. Sent ${relevantChallenges.length} incoming challenges');
                if (asGreeting)
                    user.emit(GreetingResponse(Logged(user.sessionID, Auth.getTokenBySessionID(user.sessionID), relevantChallenges, null, Shutdown.isStopping())));
                else
                    user.emit(LoginResult(Success(relevantChallenges)));
            }
            else 
            {
                switch GameManager.get(finiteGameID) 
                {
                    case OngoingFinite(game):
                        Logger.serviceLog('LOGIN', 'Login successful for $login, but reconnection to game $finiteGameID is needed. Additionally sent ${relevantChallenges.length} incoming challenges');
                        
                        game.onPlayerJoined(user);

                        var info:OngoingGameInfo = OngoingGameInfo.create(finiteGameID, game.getTime(), game.log.get());
                        if (asGreeting)
                            user.emit(GreetingResponse(Logged(user.sessionID, Auth.getTokenBySessionID(user.sessionID), relevantChallenges, info, Shutdown.isStopping())));
                        else
                            user.emit(LoginResult(ReconnectionNeeded(relevantChallenges, info)));

                        game.resendPendingOffers(user);
                    default:
                        Logger.serviceLog('LOGIN', 'Login successful for $login. Sent ${relevantChallenges.length} incoming challenges');

                        user.ongoingFiniteGameID = null;

                        if (asGreeting)
                            user.emit(GreetingResponse(Logged(user.sessionID, Auth.getTokenBySessionID(user.sessionID), relevantChallenges, null, Shutdown.isStopping())));
                        else
                            user.emit(LoginResult(Success(relevantChallenges)));
                }
            }
        }
    }

    public static function register(user:UserSession, login:String, password:String) 
    {
        Logger.serviceLog('LOGIN', '$user attempts registering as $login');
        if (!Auth.userExists(login))
        {
            Auth.addCredentials(login, password);
            user.onLoggedIn(login);
            loggedUserByLogin.set(login, user);
            user.emit(RegisterResult(Success));
            Logger.serviceLog('LOGIN', 'New user $login registered successfully');
        }
        else
        {
            user.emit(RegisterResult(Fail));
            Logger.serviceLog('LOGIN', 'Registration failed for $user: user $login already exists');
        }
    }

    public static function logout(user:UserSession)
    {
        if (user.login == null)
            return;

        loggedUserByLogin.remove(user.login);
        user.onLoggedOut();
        Logger.serviceLog('LOGIN', 'Logged ${user.login} ($user) out');
    }

    public static function handleSessionDestruction(user:UserSession)
    {
        if (user.login != null)
            logout(user);
    }
}