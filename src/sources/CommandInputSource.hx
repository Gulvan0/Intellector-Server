package sources;

import processors.CommandProcessor;
import processors.nodes.struct.Command;
import processors.nodes.struct.CommandArgument;

using hx.strings.Strings;
using Lambda;

class CommandInputSource 
{
    private final printCallback:String->Void;

    private var interactiveCommand:Null<Command>;
    private var interactiveArgsSaved:Array<Dynamic> = [];
    private var expectedInteractiveArgs:Array<CommandArgument> = [];

    private function printNextExpectedArg()
    {
        var s:String = 'Please input next argument\n';
        s += expectedInteractiveArgs[0].describe();
        printCallback(s);
    }

    public function processString(str:String) 
    {
        if (interactiveCommand != null)
        {
            var nextArg:CommandArgument = expectedInteractiveArgs.shift();
            if (str != "")
                interactiveArgsSaved.push(nextArg.obtainValue(str));
            else if (!nextArg.required)
                interactiveArgsSaved.push(nextArg.obtainValue(null));
            else if (nextArg.allowsEmptyString())
                interactiveArgsSaved.push("");
            else
            {
                printCallback('Argument ${nextArg.name} is required and cannot be empty');

                interactiveCommand = null;
                interactiveArgsSaved = [];
                expectedInteractiveArgs = [];

                return;
            }
            
            if (expectedInteractiveArgs.empty())
            {
                CommandProcessor.processCommand(interactiveCommand, interactiveArgsSaved, printCallback);

                interactiveCommand = null;
                interactiveArgsSaved = [];
            }
            else
                printNextExpectedArg();
        }

        var parts:Array<String> = str.split8(" ", 2);

        var command:Null<Command> = Command.fromString(parts[0]);

        if (command == null)
        {
            printCallback('Unknown command ${parts[0]}. Use help to get a list of available commands');
            return;
        }

        var args:Array<CommandArgument> = command.getArgs();

        if (parts.length == 2)
        {
            var argCnt:Int = args.length;
            var argParts:Array<String> = parts[1].split8(" ", argCnt);
            var partsCnt:Int = argParts.length;

            var argValues:Array<Dynamic> = [];
            
            for (i => arg in args.keyValueIterator())
                if (i < partsCnt)
                    argValues.push(arg.obtainValue(argParts[i]));
                else if (!arg.required)
                    argValues.push(null);
                else
                {
                    printCallback('Not enough arguments: specified $partsCnt, but argument ${i+1} (${arg.name}) is required');
                    return;
                }

            CommandProcessor.processCommand(command, argValues, printCallback);
        }
        else
        {
            interactiveCommand = command;
            expectedInteractiveArgs = args;
            printNextExpectedArg();
        }    
    }

    public function new(printCallback:String->Void) 
    {
        this.printCallback = printCallback;
    }    
}