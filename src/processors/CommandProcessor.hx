package processors;

import processors.nodes.struct.CommandArgument;
import processors.nodes.struct.Command;

using Lambda;

class CommandProcessor 
{
    private static function printHelp(printCallback:String->Void) 
    {
        var s:String = "Available commands:";

        for (cmd in Command.createAll())
        {
            s += '\n\n${cmd.getName()}';

            var aliases:Array<String> = cmd.getAliases();
            if (!aliases.empty())
                s += ' (aliases: ${aliases.join(", ")})';

            var args:Array<CommandArgument> = cmd.getArgs();
            if (!args.empty())
            {
                s += '\nArgs:';
                for (i => arg in args.keyValueIterator())
                    s += '\n$i\n' + arg.describe();
            }
            else
                s += '\nNo arguments';
        }

        printCallback(s);
    }

    public static function processCommand(command:Command, args:Array<Dynamic>, printCallback:String->Void) 
    {
        //TODO: Fill every case
        switch command 
        {
            case Help:
                printHelp(printCallback);
            case GetOnlineUsers:
            case GetQueries:
            case ExecuteQuery:
            case ExecuteNamedQuery:
            case AddQuery:
            case DeleteQuery:
            case Stop:
            case ResetPwd:
            case BanElo:
            case LiftBans:
            case GetRoles:
            case AddRole:
            case RemoveRole:
        }
    }
}