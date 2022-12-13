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

    public static function load(log:LogType):String 
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

        if (totalEntries > 0)
            return 'Loaded successfully\n\n' + current();
        else
            return 'Loaded, but no entries found';
    }

    public static function current():String
    {
        return 'Entry ${cursor+1}/$totalEntries\n\n' + loadedLog[cursor].entry;
    }

    public static function prev(?n:Int = 1):String
    {
        var slice:Array<String> = [];
        var cnt:Int = 0;
        var to:Int = cursor;

        while (cnt < n && cursor > 0)
        {
            cursor--;

            var currentEntry:String = loadedLog[cursor].entry;
            if (logFilter.passes(currentEntry))
            {
                slice.unshift(currentEntry);
                cnt++;
            }
        }

        if (Lambda.empty(slice))
            return 'No entries. Current: ${cursor+1}/$totalEntries';
        else
            return 'Entries ${cursor+1}-$to of $totalEntries\n\n' + slice.join('\n\n');
    }

    public static function next(?n:Int = 1):String
    {
        var slice:Array<String> = [];
        var cnt:Int = 0;
        var from:Int = cursor + 2;

        while (cnt < n && cursor < totalEntries - 1)
        {
            cursor++;

            var currentEntry:String = loadedLog[cursor].entry;
            if (logFilter.passes(currentEntry))
            {
                slice.push(currentEntry);
                cnt++;
            }
        }

        if (Lambda.empty(slice))
            return 'No entries. Current: ${cursor+1}/$totalEntries';
        else
            return 'Entries $from-${cursor+1} of $totalEntries\n\n' + slice.join('\n\n');
    }

    public static function skip(interval:TimeInterval):String
    {
        var backwards:Bool = interval.isNegative();
        var currentData:LogEntryData = loadedLog[cursor];

        var desiredTS:Int = currentData.ts + Math.floor(interval.toSeconds());
        var currentEntry:String = currentData.entry;
        
        if (backwards)
            while (cursor > 0)
            {
                cursor--;

                currentData = loadedLog[cursor];
                currentEntry = currentData.entry;

                if (currentData.ts < desiredTS && logFilter.passes(currentEntry))
                    break;
            }
        else
            while (cursor < totalEntries - 1)
            {
                cursor++;

                currentData = loadedLog[cursor];
                currentEntry = currentData.entry;

                if (currentData.ts > desiredTS && logFilter.passes(currentEntry))
                    break;
            }

        return current();
    }

    public static function prevdate():String
    {
        var currentData:LogEntryData = loadedLog[cursor];

        var minTS:Int = currentData.ts - UnixSecs.Day;
        var thisDate:Int = Date.fromTime(currentData.ts * 1000).getDate();
        var currentEntry:String = "Reached the end";
        
        while (cursor > 0)
        {
            cursor--;

            currentData = loadedLog[cursor];
            currentEntry = currentData.entry;

            if ((currentData.ts < minTS || Date.fromTime(currentData.ts * 1000).getDate() != thisDate) && logFilter.passes(currentEntry))
                break;
        }

        return current();
    }

    public static function nextdate():String
    {
        var currentData:LogEntryData = loadedLog[cursor];

        var maxTS:Int = currentData.ts + UnixSecs.Day;
        var thisDate:Int = Date.fromTime(currentData.ts * 1000).getDate();
        var currentEntry:String = "Reached the end";
        
        while (cursor < totalEntries - 1)
        {
            cursor++;

            currentData = loadedLog[cursor];
            currentEntry = currentData.entry;

            if ((currentData.ts > maxTS || Date.fromTime(currentData.ts * 1000).getDate() != thisDate) && logFilter.passes(currentEntry))
                break;
        }

        return current();
    }
}