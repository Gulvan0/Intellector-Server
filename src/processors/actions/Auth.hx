package processors.actions;

import net.shared.dataobj.SignInResult;
import net.shared.message.ServerRequestResponse;
import net.shared.dataobj.ChallengeData;
import entities.Challenge;
import processors.nodes.Sessions;
import processors.nodes.struct.UserSession;
import haxe.crypto.Md5;
import database.endpoints.Player;
import database.Database;
import processors.actions.returned.CredentialsCheckResult;

class Auth 
{
    public static function checkCredentials(login:String, password:String):CredentialsCheckResult
    {
        var passwordHash:Null<String> = Player.getPasswordHash(login);

        if (passwordHash == null)
            return PlayerNotFound;
        else if (passwordHash != Md5.encode(password))
            return WrongPassword;
        else
            return Valid;
    }

    public static function login(session:UserSession, login:String, password:String):SignInResult
    {
        logInfo('Session ${session.id} attempts logging in as $login');

        var checkResult:CredentialsCheckResult = checkCredentials(login, password);

        logInfo('Credentials check result for session ${session.id} returned $checkResult');

        if (checkResult != Valid)
            return Fail;

        //TODO: Broadcast: player status update; new session for login???
        
        var incomingChallenges:Array<ChallengeData> = Challenge.getActiveIncoming(login);
        return Success(incomingChallenges);
    }

    public static function logout(session:UserSession) 
    {
        Sessions.setLogin(session, null);

        //TODO: Propagate login update event???
    }
}