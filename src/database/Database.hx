package database;

import config.Config;
import sys.db.Mysql;
import sys.db.ResultSet;
import haxe.Resource;
import sys.db.Connection;

using StringTools;

class Database 
{
    private var mainConnection:Connection;

    public function executeQuery(resourceName:String, ?replacements:Map<String, Dynamic>, ?getInsertID:Bool = false, ?customConnection:Connection):QueryExecutionResult
    {
        var queryText:Null<String> = Resource.getString(resourceName);

        if (queryText == null)
        {
            Logging.error("database", 'Failed to retrieve a query from $resourceName');
            return null;
        }

        if (replacements != null)
            for (sub => by in replacements.keyValueIterator())
                queryText = queryText.replace('{$sub}', Std.string(by));

        var usedConnection:Connection = customConnection ?? mainConnection;
        var resultSet:ResultSet = usedConnection.request(queryText);
        var lastID:Int = -1;

        if (getInsertID)
            lastID = usedConnection.lastInsertId();

        return {set: resultSet, lastID: lastID};
    }

    public function repairGameLogs() 
    {
        var prefix:String = "sql/dml/on_start/clean_short_term_tables/";
        var gameIDs:ResultSet = executeQuery(prefix + "get_unfinished_games.sql").set;

        for (i in 0...gameIDs.length)
        {
            var gameID:Int = gameIDs.getIntResult(i);
            var eventID:Int = executeQuery(prefix + "append_to_common.sql", ["game_id" => gameID], true).lastID;
            executeQuery(prefix + "append_to_game_ended.sql", ["event_id" => eventID]);
        }
    }

    private function createTables() 
    {
        for (resourceName in Resource.listNames())
            if (resourceName.startsWith("sql/ddl/"))
                executeQuery(resourceName);
    }

    private function cleanTablesOnLaunch()
    {
        for (resourceName in Resource.listNames())
            if (resourceName.startsWith("sql/dml/on_start/clean_short_term_tables/"))
                executeQuery(resourceName);
    }

    public function new()
    {
        mainConnection = Mysql.connect({
            host: Config.config.mysqlHost,
            port: Config.config.mysqlPort,
            user: Config.config.mysqlUser,
            pass: Config.config.mysqlPass
        });

        var isEmpty:Bool = executeQuery("sql/dml/on_start/is_empty/check_if_database_empty.sql").set.length == 0;

        if (isEmpty)
        {
            Logging.info("database", "Database seems to be fresh, filling it with tables...");
            createTables();
        }
        else
        {
            Logging.info("database", "It seems database is already initialized. Cleaning short-term tables...");
            cleanTablesOnLaunch();
        }
    }
}