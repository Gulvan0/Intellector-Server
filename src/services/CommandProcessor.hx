package services;

import services.util.Command;
import net.shared.dataobj.UserRole;
import services.util.AnyGame;
import entities.Game;
import net.shared.utils.MathUtils;
import entities.UserSession;

using StringTools;
using hx.strings.Strings;

class CommandProcessor 
{
    private static function printHelp(callback:String->Void) 
    {
        var s:String = "Available commands: ";

        for (cmd in Command.createAll())
            s += '\n' + cmd.getName().toLowerCase();

        callback(s);
    }

    //TODO:
    /*
        1. Player queries tables
        2. TG attachments
        3. Query result to string (tsv probably)
        4. Account for failed queries
        5. Add query / remove query / execute named query / execute anon query / save last successful anon query commands
        6. Think about commands for easier log quering and navigation
        7. Commands for printing game/challenge/logged players infos (+ choose format)
        8. Ban elo command
        9. Update pwd command
        10. Add/remove role commands
        11. Cleanup (also check one-time tasks) + update Command.hx
        12. Extend Service.hx
    */

    public static function processCommand(rawText:String, callback:String->Void) 
    {
        var parts:Array<String> = rawText.split(' ');
        var commandStr:String = parts[0].toLowerCase();
        var args = parts.slice(1);

        var command:Command = null;
        for (cmd in Command.createAll())
            if (cmd.getName().toLowerCase() == commandStr)
            {
                command = cmd;
                break;
            }

        if (command == null)
        {
            Logger.serviceLog('COMMAND', 'Tried to execute non-existing command: $rawText');
            callback("Command doesn't exist");
            printHelp(callback);
            return;
        }

        Logger.serviceLog('COMMAND', 'Executing command: $rawText');

        try 
        {
            switch command
            {
                case Help:
                    printHelp(callback);
                case Logged:
                    var users:Array<UserSession> = LoginManager.getLoggedUsers();
                    callback(users.map(x -> x.login).toString());
                case Lload if (args.length > 0):
                    callback(LogReader.load(LogType.createByName(args[0])));
                case Lcurrent:
                    callback(LogReader.current());
                case Lskip if (args.length > 0):
                    callback(LogReader.skip(args[0]));
                case Lprev:
                    if (args.length > 0)
                        callback(LogReader.prev(Std.parseInt(args[0])));
                    else
                        callback(LogReader.prev());
                case Lnext:
                    if (args.length > 0)
                        callback(LogReader.next(Std.parseInt(args[0])));
                    else
                        callback(LogReader.next());
                case Lprevdate:
                    callback(LogReader.prevdate());
                case Lnextdate:
                    callback(LogReader.nextdate());
                case Addfilter if (args.length > 2):
                    addFilter(callback, args);
                case Rmfilter if (args.length > 2):
                    removeFilter(callback, args);
                case Getfilters if (args.length > 1):
                    getFilters(callback, args);
                case Games:
                    games(callback, args);
                case Challenges:
                    challenges(callback, args);
                case Profile if (args.length > 0):
                    callback(Storage.read(PlayerData(args[0].toLowerCase())));
                case Game if (args.length > 0):
                    callback(Storage.read(GameData(Std.parseInt(args[0]))));
                case Kick if (args.length > 0):
                    LoginManager.getUser(args[0].toLowerCase()).abortConnection(true);
                    callback("Kicked successfully. Remaining players:");
                    var users:Array<UserSession> = LoginManager.getLoggedUsers();
                    callback(users.map(x -> x.login).toString());
                case Pwd if (args.length > 1):
                    var login:String = args[0].toLowerCase();
                    Auth.addCredentials(login, args[1]);
                    callback('Credentials added. New hash for $login is ${Auth.getHash(login)}');
                case Stop:
                    callback("Stopping the server...");
                    Shutdown.stop(false);
                case Forcestop:
                    callback("Forcefully stopping the server...");
                    Shutdown.stop(true);
                case Addrole if (args.length > 1):
                    var session = LoginManager.getUser(args[0]);
                    var role:UserRole = UserRole.createByName(args[1]);
                    if (session != null)
                        session.storedData.addRole(role);
                    else
                        Storage.loadPlayerData(args[0]).addRole(role);
                case Rmrole if (args.length > 1):
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
                case Roles if (args.length > 0):
                    var session = LoginManager.getUser(args[0]);
                    if (session != null)
                        callback(session.storedData.getRoles().map(x -> x.getName()).join(", "));
                    else
                        callback(Storage.loadPlayerData(args[0]).getRoles().map(x -> x.getName()).join(", "));
                case RecountGames:
                    callback("Starting recount...");
                    OneTimeTasks.recountGames();
                    callback("Recount finished successfully");
                default:
                    callback("Wrong number of arguments");
            }
        }
        catch (e)
        {
            trace(e.details());
            callback(e.details());
        }
    }
}