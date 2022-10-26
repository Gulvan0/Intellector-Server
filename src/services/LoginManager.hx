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
        if (Auth.isValid(login, password))
        {
            if (loggedUserByLogin.exists(login))
                loggedUserByLogin.get(login).abortConnection(true);

            loggedUserByLogin.set(login, user);
            user.onLoggedIn(login);

            var incomingChallenges:Array<ChallengeData> = ChallengeManager.getAllIncomingChallengesByReceiverLogin(login);
            var finiteTimeGame:Null<FiniteTimeGame> = GameManager.getFiniteTimeGameByPlayer(user);

            if (finiteTimeGame == null)
                user.emit(LoginResult(Success(incomingChallenges)));
            else 
            {
                user.emit(LoginResult(ReconnectionNeeded(incomingChallenges, finiteTimeGame.id, finiteTimeGame.getTime(), finiteTimeGame.log.get())));
                GameManager.onSpecialReconnection(finiteTimeGame.id, user);
            }
        }
        else 
            user.emit(LoginResult(Fail));
    }

    public static function register(user:UserSession, login:String, password:String) 
    {
        if (Auth.userExists(login))
        {
            Auth.addCredentials(login, password);
            user.onLoggedIn(login);
            loggedUserByLogin.set(login, user);
            user.emit(RegisterResult(Success([])));
        }
        else
            user.emit(RegisterResult(Fail));
    }

    public static function logout(user:UserSession)
    {
        if (user.login == null)
            return;

        loggedUserByLogin.remove(user.login);
        user.onLoggedOut();
    }

    public static function handleDisconnection(user:UserSession) 
    {
        if (user.login != null)
            logout(user);
    }

    public static function handleReconnection(user:UserSession) 
    {
        if (user.login != null)
            loggedUserByLogin.set(user.login, user);
    }
}