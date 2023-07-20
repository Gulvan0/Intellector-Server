package database;

import database.QueryShortcut;
import config.Config;
import sys.db.Mysql;
import sys.db.ResultSet;
import haxe.Resource;
import sys.db.Connection;
import database.QueryShortcut;

using StringTools;

class Database 
{
    private var mainConnection:Connection;

    public function executeQuery(resourceName:String, ?replacements:Map<String, Dynamic>, ?getInsertID:Bool = false, ?customConnection:Connection):Array<QueryExecutionResult>
    {
        var queryText:Null<String> = Resource.getString(resourceName);

        if (queryText == null)
        {
            Logging.error("database", 'Failed to retrieve a query from $resourceName');
            return null;
        }

        if (replacements != null)
            for (sub => by in replacements.keyValueIterator())
            {
                var trueReplacement:String;
                if (by == null)
                    trueReplacement = "NULL";
                else if (Std.isOfType(by, Int) || Std.isOfType(by, Float))
                    trueReplacement = Std.string(by);
                else if (Std.isOfType(by, Bool))
                    trueReplacement = by? "1" : "0";
                else
                    trueReplacement = '\'$by\'';
                queryText = queryText.replace('{$sub}', trueReplacement);
            }

        var usedConnection:Connection = customConnection ?? mainConnection;
        var individualQueries:Array<String> = queryText.split(";");
        var lastID:Int = -1;
        var output:Array<QueryExecutionResult> = [];

        for (query in individualQueries)
        {
            var trimmedQuery:String = query.trim();

            if (trimmedQuery.length == 0)
                continue;

            var finalQuery:String = trimmedQuery.replace("{LAST_INSERT_ID}", Std.string(lastID));
            var resultSet:ResultSet = usedConnection.request(finalQuery);

            if (getInsertID)
                lastID = usedConnection.lastInsertId();
    
            output.push({set: resultSet, lastID: lastID});
        }
        
        return output;
    }

    public function repairGameLogs() 
    {
        var gameIDs:ResultSet = executeQuery(GetUnfinishedFiniteGames)[0].set;

        for (i in 0...gameIDs.length)
        {
            var gameID:Int = gameIDs.getIntResult(i);
            var substitutions:Map<String, Dynamic> = [
                "game_id" => gameID, 
                "event_id" => eventID, 
                "outcome_type" => "abort", 
                "winner_color" => null
            ];
            executeQuery(OnGameEnded, substitutions);
        }
    }

    private function createTables() 
    {
        for (resourceName in Resource.listNames()) //TODO: Needs to be recursive
            if (resourceName.startsWith("sql/ddl/"))
            {
                executeQuery(resourceName);
                Logging.info("database", 'Executed $resourceName');
            }
    }

    private function cleanTablesOnLaunch()
    {
        for (resourceName in Resource.listNames())
            if (resourceName.startsWith("sql/dml/on_start/clean_short_term_tables/")) //TODO: Fill dir
            {
                executeQuery(resourceName);
                Logging.info("database", 'Executed $resourceName');
            }
    }

    public function new()
    {
        mainConnection = Mysql.connect({
            host: Config.config.mysqlHost,
            port: Config.config.mysqlPort,
            user: Config.config.mysqlUser,
            pass: Config.config.mysqlPass
        });

        var isEmpty:Bool = executeQuery(CheckDatabaseEmptyness)[0].set.length == 0;

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