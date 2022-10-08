package services;

import entities.UserSession;

class LoginManager 
{
    private static var loggedUserByLogin:Map<String, UserSession> = [];

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
            user.emit(LoginResult(Success(ChallengeManager.getAllIncomingChallengesByReceiverLogin(login))));
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