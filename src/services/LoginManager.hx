package services;

import entities.User;

class LoginManager 
{
    private static var loggedUsersByLogin:Map<String, User> = [];

    //TODO: Fill

    /*
    on disconnected:
        if (user.login != null)
            data.loggedUsersByLogin.remove(user.login);

    

    private static function onLogin(user:User, login:String, password:String) 
    {
        if (Auth.isValid(login, password))
        {
            user.signIn(login);
            data.loggedUsersByLogin.set(login, user);
            //TODO: Handle reconnection
            user.emit(LoginResult(Success([]))); //TODO: get and send incoming challenges
        }
        else 
            user.emit(LoginResult(Fail));
    }
    */
}