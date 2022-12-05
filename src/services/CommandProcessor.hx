package services;

import net.shared.dataobj.UserRole;
import services.util.AnyGame;
import entities.Game;
import net.shared.utils.MathUtils;
import services.Storage.LogType;
import entities.UserSession;

using StringTools;

class CommandProcessor 
{ 
    private static function games(callback:String->Void, args:Array<String>)
    {
        for (gameInfo in GameManager.getCurrentFiniteTimeGames())
        {
            var anyGame:AnyGame = GameManager.get(gameInfo.id);

            switch anyGame 
            {
                case OngoingFinite(game):
                    var desc:String = 'Game ${gameInfo.id}\n';
                    desc += game.log.getEntries().map(Std.string).join('\n');
                    desc += 'Time left: White ' + MathUtils.roundTo(game.getTime().whiteSeconds, -2) + 's, Black ' + MathUtils.roundTo(game.getTime().blackSeconds, -2) + 's';
                    callback(desc);
                case OngoingCorrespondence(game):
                    callback('Oops! Game with ID ${gameInfo.id} is considered finite, but is actually correspondence');
                case Past(log):
                    callback('Oops! Game with ID ${gameInfo.id} is considered ongoing, but has actually already ended');
                case NonExisting:
                    callback('Oops! Game with ID ${gameInfo.id} is considered ongoing, but actually does not exist');
            }
        }
    }

    private static function challenges(callback:String->Void, args:Array<String>)
    {
        var challenges = ChallengeManager.getAllPendingChallenges();

        if (Lambda.empty(challenges))
            callback('No challenges found');
        else
            for (challengeInfo in challenges)
            {
                var desc:String = 'Challenge ${challengeInfo.id} by ${challengeInfo.ownerLogin}\n';
                desc += 'Type: ${challengeInfo.params.type}\n';
                desc += 'Time control: ${challengeInfo.params.timeControl.toString(false)}\n';
                desc += 'Rated: ${challengeInfo.params.rated}\n';
                if (challengeInfo.params.customStartingSituation != null)
                    desc += 'Custom SIP: ${challengeInfo.params.customStartingSituation.serialize()}\n';
                desc += 'Acceptor color: ${challengeInfo.params.acceptorColor}';
                callback(desc);
            }
    }

    private static function addFilter(callback:String->Void, args:Array<String>) 
    {
        if (args[1] != "re" && args[1] != "str")
        {
            callback("Invalid second arg: must be one of 're', 'str'");
            return;
        }

        var entry:String = args.slice(2).join(' ');
        var regexp:Bool = args[1] == "re";

        if (args[0] == "log")
            LogReader.logFilter.addBlacklistEntry(entry, regexp);
        else if (args[0] == "alert")
            IntegrationManager.alertFilter.addBlacklistEntry(entry, regexp);
        else
            callback("Invalid first arg: must be one of 'log', 'alert'");
    }

    private static function removeFilter(callback:String->Void, args:Array<String>) 
    {
        if (args[1] != "re" && args[1] != "str")
        {
            callback("Invalid second arg: must be one of 're', 'str'");
            return;
        }

        var entry:String = args.slice(2).join(' ');
        var regexp:Bool = args[1] == "re";

        if (args[0] == "log")
            LogReader.logFilter.removeBlacklistEntry(entry, regexp);
        else if (args[0] == "alert")
            IntegrationManager.alertFilter.removeBlacklistEntry(entry, regexp);
        else
            callback("Invalid first arg: must be one of 'log', 'alert'");
    }

    private static function getFilters(callback:String->Void, args:Array<String>) 
    {
        if (args[1] != "re" && args[1] != "str")
        {
            callback("Invalid second arg: must be one of 're', 'str'");
            return;
        }

        var regexp:Bool = args[1] == "re";

        if (args[0] == "log")
            callback(LogReader.logFilter.getBlacklistEntries(regexp).join('\n'));
        else if (args[0] == "alert")
            callback(IntegrationManager.alertFilter.getBlacklistEntries(regexp).join('\n'));
        else
            callback("Invalid first arg: must be one of 'log', 'alert'");
    }

    public static function processCommand(rawText:String, callback:String->Void) 
    {
        var parts = rawText.split(' ');
        var command = parts[0];
        var args = parts.slice(1);

        Logger.serviceLog('COMMAND', 'Executing command: $rawText');

        try 
        {
            switch command
            {
                case "logged":
                    var users:Array<UserSession> = LoginManager.getLoggedUsers();
                    callback(users.map(x -> x.login).toString());
                case "lload" if (args.length > 0):
                    LogReader.load(LogType.createByName(args[0]));
                    callback("Loaded");
                case "lskip" if (args.length > 0):
                    callback(LogReader.skip(args[0]));
                case "lprev":
                    if (args.length > 0)
                        callback(LogReader.prev(Std.parseInt(args[0])));
                    else
                        callback(LogReader.prev());
                case "lnext":
                    if (args.length > 0)
                        callback(LogReader.next(Std.parseInt(args[0])));
                    else
                        callback(LogReader.next());
                case "lprevdate":
                    callback(LogReader.prevdate());
                case "lnextdate":
                    callback(LogReader.nextdate());
                case "addfilter" if (args.length > 2):
                    addFilter(callback, args);
                case "rmfilter" if (args.length > 2):
                    removeFilter(callback, args);
                case "getfilters" if (args.length > 1):
                    getFilters(callback, args);
                case "games":
                    games(callback, args);
                case "challenges":
                    challenges(callback, args);
                case "profile" if (args.length > 0):
                    callback(Storage.read(PlayerData(args[0].toLowerCase())));
                case "game" if (args.length > 0):
                    callback(Storage.read(GameData(Std.parseInt(args[0]))));
                case "kick" if (args.length > 0):
                    LoginManager.getUser(args[0].toLowerCase()).abortConnection(true);
                    callback("Kicked successfully. Remaining players:");
                    var users:Array<UserSession> = LoginManager.getLoggedUsers();
                    callback(users.map(x -> x.login).toString());
                case "pwd" if (args.length > 1):
                    Auth.addCredentials(args[0], args[1]);
                    callback('Credentials added. New hash for ${args[0]} is ${Auth.getHash(args[0])}');
                case "stop":
                    callback("Stopping the server...");
                    Shutdown.stop(false);
                case "forcestop":
                    callback("Forcefully stopping the server...");
                    Shutdown.stop(true);
                case "addrole" if (args.length > 1):
                    var session = LoginManager.getUser(args[0]);
                    var role:UserRole = UserRole.createByName(args[1]);
                    if (session != null)
                        session.storedData.addRole(role);
                    else
                        Storage.loadPlayerData(args[0]).addRole(role);
                case "rmrole" if (args.length > 1):
                    var session = LoginManager.getUser(args[0]);
                    var role:UserRole = UserRole.createByName(args[1]);
                    if (session != null)
                    {
                        session.storedData.removeRole(role);
                        callback("Success. Updated roles are:");
                        callback(session.storedData.getRoles().map(x -> x.getName()).join(", "));
                    }
                    else
                    {
                        Storage.loadPlayerData(args[0]).removeRole(role);
                        callback("Success. Updated roles are:");
                        callback(Storage.loadPlayerData(args[0]).getRoles().map(x -> x.getName()).join(", "));
                    }
                case "roles" if (args.length > 0):
                    var session = LoginManager.getUser(args[0]);
                    if (session != null)
                        callback(session.storedData.getRoles().map(x -> x.getName()).join(", "));
                    else
                        callback(Storage.loadPlayerData(args[0]).getRoles().map(x -> x.getName()).join(", "));
                default:
                    callback("Malformed command");
            }
        }
        catch (e)
        {
            trace(e.details());
            callback(e.details());
        }
    }
}