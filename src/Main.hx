import services.OneTimeTasks;
import net.ServerManager;

class Main 
{
	public static function main() 
	{
        Routines.onStartup();
        OneTimeTasks.gatherGameArchiveCSV();
        //ServerManager.start();
    }
}