package processors.nodes.struct;

import net.shared.dataobj.UserRole;
import net.shared.utils.TimeInterval;

enum InternalCommand
{
    Help;
    GetOnlineUsers;
    GetQueries;
    ExecuteQuery;
    ExecuteNamedQuery;
    AddQuery;
    DeleteQuery;
    Stop;
    ResetPwd;
    BanElo;
    LiftBans;
    GetRoles;
    AddRole;
    RemoveRole;
}

@:forward abstract Command(InternalCommand) from InternalCommand to InternalCommand 
{
    public static function createAll():Array<Command>
    {
        return InternalCommand.createAll();
    }

    public static function fromString(str:String):Null<Command>
    {
        var lowered:String = str.toLowerCase();

        for (command in Command.createAll())
            if (command.getName().toLowerCase() == lowered || command.getAliases().contains(lowered))
                return command;

        return null;
    }

    public function concretize():InternalCommand
    {
        return this;
    }

    public function getArgs():Array<CommandArgument>
    {
        return switch this 
        {
            case Help:
                [];
            case GetOnlineUsers:
                [];
            case GetQueries:
                [new CommandArgument("hasResult", TBool(null), true), new CommandArgument("namesOnly", TBool(true)), new CommandArgument("owner", TLogin(""))];
            case ExecuteQuery:
                [new CommandArgument("text", TString(32768, null), true)];
            case ExecuteNamedQuery:
                [new CommandArgument("name", TString(40, null), true), new CommandArgument("owner", TLogin(""))];
            case AddQuery:
                [new CommandArgument("name", TString(40, null), true), new CommandArgument("text", TString(32768, null), true)];
            case DeleteQuery:
                [new CommandArgument("name", TString(40, null), true)];
            case Stop:
                [new CommandArgument("force", TBool(false))];
            case ResetPwd:
                [new CommandArgument("login", TLogin(null), true), new CommandArgument("passwordHash", TString(32, null))];
            case BanElo:
                [new CommandArgument("login", TLogin(null), true), new CommandArgument("period", TInterval(TimeInterval.weeks(2)))];
            case LiftBans:
                [new CommandArgument("login", TLogin(null), true)];
            case GetRoles:
                [new CommandArgument("login", TLogin(null), true)];
            case AddRole:
                [new CommandArgument("login", TLogin(null), true), new CommandArgument("role", TEnum(UserRole, null), true)];
            case RemoveRole:
                [new CommandArgument("login", TLogin(null), true), new CommandArgument("role", TEnum(UserRole, null), true)];
        }
    }

    public function getAliases():Array<String>
    {
        return switch this 
        {
            case Help:
                ["h"];
            case GetOnlineUsers:
                ["online", "users"];
            case GetQueries:
                ["queries"];
            case ExecuteQuery:
                ["exec"];
            case ExecuteNamedQuery:
                ["execn"];
            case AddQuery:
                ["addq"];
            case DeleteQuery:
                ["removequery", "rmquery", "rmq"];
            case Stop:
                [];
            case ResetPwd:
                ["resetpassword"];
            case BanElo:
                [];
            case LiftBans:
                ["rmbans", "forgive"];
            case GetRoles:
                ["roles"];
            case AddRole:
                ["addr"];
            case RemoveRole:
                ["rmrole", "rmr"];
        }
    }
}