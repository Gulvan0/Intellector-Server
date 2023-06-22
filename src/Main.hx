import services.ServerManager;

class Main 
{
	public static function main() 
	{
        Routines.onStartup();
        ServerManager.start();
    }
}