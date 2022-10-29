package services;

import net.shared.ChallengeData;
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

    public static function login(user:UserSession, login:String, password:String) 
    {
        Logger.serviceLog('LOGIN', '${user.getLogReference()} attempts logging in as $login');
        if (Auth.isValid(login, password))
        {
            if (loggedUserByLogin.exists(login))
                loggedUserByLogin.get(login).abortConnection(true);

            loggedUserByLogin.set(login, user);
            user.onLoggedIn(login);

            var incomingChallenges:Array<ChallengeData> = ChallengeManager.getAllIncomingChallengesByReceiverLogin(login);
            var finiteGameID:Null<Int> = user.ongoingFiniteGameID;

            if (finiteGameID == null)
            {
                Logger.serviceLog('LOGIN', 'Login successful for $login. Sent ${incomingChallenges.length} incoming challenges');
                user.emit(LoginResult(Success(incomingChallenges)));
            }
            else 
            {
                switch GameManager.get(finiteGameID) 
                {
                    case OngoingFinite(game):
                        Logger.serviceLog('LOGIN', 'Login successful for $login, but reconnection to game $finiteGameID is needed. Additionally sent ${incomingChallenges.length} incoming challenges');
                        user.emit(LoginResult(ReconnectionNeeded(incomingChallenges, finiteGameID, game.getTime(), game.log.get())));
                        user.viewedGameID = finiteGameID;
                        GameManager.handleReconnection(user);
                    default:
                        user.ongoingFiniteGameID = null;
                        user.emit(LoginResult(Success(incomingChallenges)));
                }
            }
        }
        else 
        {
            Logger.serviceLog('LOGIN', 'Failed to log ${user.getLogReference()} in as $login: invalid password');
            user.emit(LoginResult(Fail));
        }
    }

    public static function register(user:UserSession, login:String, password:String) 
    {
        Logger.serviceLog('LOGIN', '${user.getLogReference()} attempts registering as $login');
        if (!Auth.userExists(login))
        {
            Auth.addCredentials(login, password);
            user.onLoggedIn(login);
            loggedUserByLogin.set(login, user);
            user.emit(RegisterResult(Success([])));
            Logger.serviceLog('LOGIN', 'New user $login registered successfully');
        }
        else
        {
            user.emit(RegisterResult(Fail));
            Logger.serviceLog('LOGIN', 'Registration failed for ${user.getLogReference()}: user $login already exists');
        }
    }

    public static function logout(user:UserSession)
    {
        if (user.login == null)
            return;

        loggedUserByLogin.remove(user.login);
        user.onLoggedOut();
        Logger.serviceLog('LOGIN', 'Logged $login (${user.getLogReference()}) out');
    }

    public static function handleSessionDestruction(user:UserSession)
    {
        if (user.login != null)
            logout(user);
    }
}