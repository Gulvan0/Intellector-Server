package services;

import entities.User;

class LoginManager 
{
    private static var loggedUserByLogin:Map<String, User> = [];

    public static function login(user:User, login:String, password:String) 
    {
        if (Auth.isValid(login, password))
        {
            user.onLoggedIn(login);
            loggedUserByLogin.set(login, user);
            user.emit(LoginResult(Success(ChallengeManager.getAllIncomingChallengesByReceiverLogin(login))));
        }
        else 
            user.emit(LoginResult(Fail));
    }

    public static function register(user:User, login:String, password:String) 
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

    public static function logout(login:String) 
    {
        loggedUserByLogin.remove(login);
    }

    public static function handleDisconnection(user:User) 
    {
        if (user.login != null)
            logout(user.login);
    }

    public static function handleReconnection(user:User) 
    {
        if (user.login != null)
            loggedUserByLogin.set(user.login, user);
    }
}