package database.endpoints;

import net.shared.utils.RegExUtils;
import haxe.Resource;
import sys.db.ResultSet;

using hx.strings.Strings;

class Job 
{
    public static function isDatabaseEmpty(database:Database):Bool
    {
        return database.simpleSet(CheckDatabaseEmptyness).length == 0;
    }

    public static function repairGameLogs(database:Database)
    {
        var gameIDs:Array<ResultRow> = database.simpleRows(GetUnfinishedFiniteGames);

        for (gameIDRow in gameIDs)
            Game.endGame(database, gameIDRow.getInt("id"), Drawish(Abort));
    }

    private static var wasCreateQueryExecuted:Map<String, Bool> = [];

    private static inline final fromRegEx:EReg = ~/FROM\s*(\w+\.\w+)/gi; 
    private static inline final joinRegEx:EReg = ~/JOIN\s*(\w+\.\w+)/gi;
    private static inline final refRegEx:EReg = ~/REFERENCES\s*(\w+\.\w+)/gi; 

    private static function performCreateQuery(database:Database, resourceName:String)
    {
        if (wasCreateQueryExecuted.exists(resourceName))
            return;

        var queryText:String = Resource.getString(resourceName);
        var isView:Bool = queryText.containsAnyIgnoreCase(["CREATE VIEW"]);

        var allMatches:Array<String> = [];

        if (isView)
            allMatches = RegExUtils.allMatches(queryText, fromRegEx, 1) + RegExUtils.allMatches(queryText, joinRegEx, 1);
        else
            allMatches = RegExUtils.allMatches(queryText, refRegEx, 1);

        for (entityName in allMatches)
            performCreateQuery(entityNameToDDLResourceName(entityName));

        database.executeQuery(resourceName);

        Logging.info("sink/database", 'Executed $resourceName');
    }

    public static function createTables(database:Database) 
    {
        for (resourceName in Resource.listNames())
            if (resourceName.startsWith("sql/ddl/"))
                performCreateQuery(database, resourceName);
    }
}