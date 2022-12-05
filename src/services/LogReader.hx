package services;

import services.util.UnixSecs;
import utils.StringFilter;
import services.util.TimeInterval;
import services.Storage.LogType;
using StringTools;

@:structInit class LogEntryData 
{
    public var ts:Int;   
    public var entry:String; 
}

class LogReader 
{
    public static var logFilter:StringFilter;

    private static var loadedLog:Array<LogEntryData> = [];
    private static var cursor:Int = 0;
    private static var totalEntries:Int = 0;

    public static function init() 
    {
        logFilter = new StringFilter("logReader");    
    }

    public static function load(log:LogType) 
    {
        loadedLog = [];
        totalEntries = 0;
        
        var lines:Array<String> = Storage.read(Log(log)).split('\n');

        var entryTS:Null<Int> = null;
        var entry:Null<String> = null;

        for (line in lines)
            if (line.charAt(0) == "|")
            {
                if (entryTS != null)
                {
                    totalEntries++;
                    loadedLog.push({ts: entryTS, entry: entry});
                }

                var splitted:Array<String> = line.substr(1).split('|');
                entryTS = Std.parseInt(splitted[0]);
                entry = splitted.slice(1).join('|');
            }
            else
            {
                if (entryTS != null)
                    entry += '\n' + line;
            }
        
        if (entryTS != null)
        {
            totalEntries++;
            loadedLog.push({ts: entryTS, entry: entry});
        }

        cursor = totalEntries - 1;
    }

    public static function prev(?n:Int = 1):String
    {
        var slice:Array<String> = [];
        var cnt:Int = 0;

        while (cnt < n && cursor >= 0)
        {
            cursor--;

            var currentEntry:String = loadedLog[cursor].entry;
            if (!logFilter.match(currentEntry))
            {
                slice.unshift(currentEntry);
                cnt++;
            }
        }

        return slice.join('\n\n');
    }

    public static function next(?n:Int = 1):String
    {
        var slice:Array<String> = [];
        var cnt:Int = 0;

        while (cnt < n && cursor < totalEntries)
        {
            cursor++;

            var currentEntry:String = loadedLog[cursor].entry;
            if (!logFilter.match(currentEntry))
            {
                slice.push(currentEntry);
                cnt++;
            }
        }

        return slice.join('\n\n');
    }

    public static function skip(interval:TimeInterval):String
    {
        var backwards:Bool = interval.isNegative();
        var current:LogEntryData = loadedLog[cursor];

        var desiredTS:Int = current.ts + Math.floor(interval.toSeconds());
        var currentEntry:String = current.entry;
        
        while (cursor >= 0 && cursor < totalEntries)
        {
            if (backwards)
                cursor--;
            else
                cursor++;

            current = loadedLog[cursor];
            currentEntry = current.entry;

            if (backwards)
            {
                if (current.ts > desiredTS && !logFilter.match(currentEntry))
                    break;
            }
            else
            {
                if (current.ts < desiredTS && !logFilter.match(currentEntry))
                    break;
            }
        }

        return currentEntry;
    }

    public static function prevdate():String
    {
        var current:LogEntryData = loadedLog[cursor];

        var minTS:Int = current.ts - UnixSecs.Day;
        var thisDate:Int = Date.fromTime(current.ts * 1000).getDate();
        var currentEntry:String = "Reached the end";
        
        while (cursor >= 0)
        {
            cursor--;

            var current = loadedLog[cursor];
            currentEntry = current.entry;

            if ((current.ts < minTS || Date.fromTime(current.ts * 1000).getDate() != thisDate) && !logFilter.match(currentEntry))
                break;
        }

        return currentEntry;
    }

    public static function nextdate():String
    {
        var current:LogEntryData = loadedLog[cursor];

        var maxTS:Int = current.ts + UnixSecs.Day;
        var thisDate:Int = Date.fromTime(current.ts * 1000).getDate();
        var currentEntry:String = "Reached the end";
        
        while (cursor < totalEntries)
        {
            cursor++;

            var current = loadedLog[cursor];
            currentEntry = current.entry;

            if ((current.ts > maxTS || Date.fromTime(current.ts * 1000).getDate() != thisDate) && !logFilter.match(currentEntry))
                break;
        }

        return currentEntry;
    }
}