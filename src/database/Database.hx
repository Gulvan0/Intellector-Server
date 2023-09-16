package database;

import ftk.format.template.Parser;
import ftk.format.template.Interp;
import database.endpoints.Job;
import database.QueryShortcut;
import config.Config;
import sys.db.Mysql;
import sys.db.ResultSet;
import haxe.Resource;
import sys.db.Connection;
import database.QueryShortcut;

using StringTools;
using hx.strings.Strings;

class Database 
{
    public static var instance:Database;

    private var mainConnection:Connection;

    public static function init() 
    {
        instance = new Database();
    }

    public function startTransaction() 
    {
        mainConnection.startTransaction();
    }

    public function commit() 
    {
        mainConnection.commit();
    }

    public function executeQuery(resourceName:String, ?replacements:Map<String, Dynamic>, ?templateData:Null<Dynamic> = null, ?getInsertID:Bool = false, ?individualQueryCnt:Int = 1, ?splittingDelimiter:String = ";", ?customConnection:Connection):Array<QueryExecutionResult>
    {
        var queryText:Null<String> = Resource.getString(resourceName);

        if (queryText == null)
        {
            Logging.error("sink/database", 'Failed to retrieve a query from $resourceName');
            return null;
        }

        if (templateData != null)
        {
            var interp:Interp = new Interp();
            var parser:Parser = new Parser();

            var parsedOutput:String = parser.parse(queryText);
		    queryText = interp.execute(parsedOutput, templateData);
        }

        if (replacements != null)
            for (sub => by in replacements.keyValueIterator())
                queryText = queryText.replace('{$sub}', Utils.toMySQLValue(by));

        var usedConnection:Connection = customConnection ?? mainConnection;
        var individualQueries:Array<String> = individualQueryCnt > 1? queryText.split8(splittingDelimiter, individualQueryCnt) : [queryText];
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

    public function insertRows(fullTableName:String, rows:Array<Array<Dynamic>>, getLastInsertID:Bool):QueryExecutionResult
    {
        var queryPrefix:String = 'INSERT INTO $fullTableName\nVALUES\n\t';

        var preparedRows:Array<String> = rows.map(Utils.toMySQLValuesRow);

        var fullQuery:String = queryPrefix + preparedRows.join(',\n\t');
        var results:Array<QueryExecutionResult> = executeQuery(fullQuery, null, null, getLastInsertID);

        return results[0];
    }

    public function insertRow(fullTableName:String, row:Array<Dynamic>, getLastInsertID:Bool):QueryExecutionResult
    {
        return insertRows(fullTableName, [row], getLastInsertID);
    }

    public function update(fullTableName:String, updates:Map<String, Dynamic>, conditions:Array<String>) 
    {
        var queryPrefix:String = 'UPDATE $fullTableName\nSET\n\t';

        var preparedUpdateLines:Array<String> = [];
        for (columnName => value in updates)
            preparedUpdateLines.push('$columnName = ${Utils.toMySQLValue(value)}');

        var fullQuery:String = queryPrefix + preparedUpdateLines.join(',\n\t') + "\nWHERE " + conditions.join("\nAND ");
        executeQuery(fullQuery);
    }

    public function filter(fullTableName:String, conditions:Array<String>, ?columns:Null<Array<String>>):ResultSet 
    {
        var selected:String = columns?.join(', ') ?? '*';
        return simpleSet('SELECT $selected\nFROM $fullTableName\nWHERE ' + conditions.join("\nAND "));
    }

    public function delete(fullTableName:String, conditions:Array<String>)
    {
        if (Lambda.empty(conditions))
            executeQuery('DELETE\nFROM $fullTableName');
        else
            executeQuery('DELETE\nFROM $fullTableName\nWHERE ' + conditions.join("\nAND "));
    }

    public function simpleSet(query:QueryShortcut, ?substitutions:Map<String, Dynamic>, ?templateData:Null<Dynamic>):ResultSet
    {
        return executeQuery(query, substitutions, templateData)[0].set;
    }

    public function simpleRows(query:QueryShortcut, ?substitutions:Map<String, Dynamic>, ?templateData:Null<Dynamic>):Array<ResultRow>
    {
        var a:Array<ResultRow> = [];

        for (row in simpleSet(query, substitutions, templateData))
            a.push(row);

        return a;
    }

    public function new()
    {
        mainConnection = Mysql.connect({
            host: Config.config.mysqlHost,
            port: Config.config.mysqlPort,
            user: Config.config.mysqlUser,
            pass: Config.config.mysqlPass
        });

        if (Job.isDatabaseEmpty(this))
        {
            Logging.info("sink/database", "Database seems to be fresh, filling it with tables...");
            Job.createTables(this);
        }
        else
        {
            Logging.info("sink/database", "It seems database is already initialized");
            Job.repairGameLogs(this);
        }
    }
}