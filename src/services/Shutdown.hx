package services;

import net.ServerManager;
import haxe.io.Path;
import sys.FileSystem;

class Shutdown 
{
    private static var stopping:Bool = false;

    public static function isStopping():Bool
    {
        return stopping;
    }

    public static function stop(immediate:Bool)
    {
        stopping = true;

        if (immediate)
        {
            Logger.serviceLog('SHUTDOWN', 'Immediate stop requested');
            GameManager.abortAllGames();
            performShutdown();
        }
        else
        {
            Logger.serviceLog('SHUTDOWN', 'Stop requested, preparing for shutdown');
            ChallengeManager.cancelAllChallenges();
            GameManager.callOnAllGamesFinished(onAllGamesFinished);
        }
    }

    private static function onAllGamesFinished() 
    {
        Logger.serviceLog('SHUTDOWN', 'All finite games were finished, shutting down...');
        performShutdown();
    }

    private static function performShutdown() 
    {
        var updatedProgramPath:String = Path.withoutExtension(Sys.programPath()) + '_new.hl';

        if (FileSystem.exists(updatedProgramPath))
        {
            ServerManager.stop(); 
            FileSystem.deleteFile(Sys.programPath());
            FileSystem.rename(updatedProgramPath, Sys.programPath());
        }

        Sys.exit(0);
    }
}