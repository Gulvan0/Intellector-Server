package processors.actions;

import haxe.io.Path;
import sys.FileSystem;
import processors.nodes.Server as ServerNode;

class Server 
{
    private static var shutdownInitialized:Bool = false;

    private static function logInfo(message:String) 
    {
        Logging.info("actions/server", message);
    }

    public static function isShuttingDown():Bool
    {
        return shutdownInitialized;
    }

    public static function stop(immediate:Bool)
    {
        shutdownInitialized = true;

        if (immediate)
        {
            logInfo('Immediate stop requested');
            //TODO: GameManager.abortAllGames();
            performShutdown();
        }
        else
        {
            logInfo('Stop requested, preparing for shutdown');
            //TODO: ChallengeManager.cancelAllChallenges();
            //TODO: GameManager.callOnAllGamesFinished(onAllGamesFinished);
        }
    }

    private static function onAllGamesFinished() 
    {
        logInfo('All finite games were finished, shutting down...');
        performShutdown();
    }

    private static function performShutdown() 
    {
        var updatedProgramPath:String = Path.withoutExtension(Sys.programPath()) + '_new.hl';

        if (FileSystem.exists(updatedProgramPath))
        {
            ServerNode.stop(); 
            FileSystem.deleteFile(Sys.programPath());
            FileSystem.rename(updatedProgramPath, Sys.programPath());
        }

        Sys.exit(0);
    }

    //TODO    
}