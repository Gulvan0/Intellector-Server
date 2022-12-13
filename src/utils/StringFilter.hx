package utils;

import services.Storage;
using StringTools;

class StringFilter 
{
    private var filterName:String;

    private var substrBlacklist:Array<String> = [];
    private var regexBlacklist:Map<String, EReg> = [];

    private function getServerDataFieldName(regex:Bool):String 
    {
        var suffix:String = regex? "regexBlacklist" : "substrBlacklist";
        return filterName + "_" + suffix;
    }

    private function saveBlacklist(regex:Bool) 
    {
        var fieldName:String = getServerDataFieldName(regex);
        var fieldValue:Array<String> = regex? [for (key in regexBlacklist.keys()) key] : substrBlacklist;

        Storage.setServerDataField(fieldName, fieldValue);
    }

    public function getBlacklistEntries(regex:Bool):Array<String> 
    {
        return regex? [for (key in regexBlacklist.keys()) key] : substrBlacklist.copy();
    }

    public function addBlacklistEntry(entry:String, regex:Bool) 
    {
        if (regex)
            if (entry.startsWith("+"))
                regexBlacklist.set(entry, new EReg(entry.substr(1), ""));
            else
                regexBlacklist.set(entry, new EReg(entry, ""));
        else
            substrBlacklist.push(entry);
        saveBlacklist(regex);
    }

    public function removeBlacklistEntry(entry:String, regex:Bool) 
    {
        if (regex)
            regexBlacklist.remove(entry);
        else
            substrBlacklist.remove(entry);
        saveBlacklist(regex);
    }

    public function clearBlacklist(regex:Bool) 
    {
        if (regex)
            regexBlacklist.clear();
        else
            substrBlacklist = [];
        saveBlacklist(regex);
    }

    public function passes(s:String):Bool
    {
        for (sub in substrBlacklist)
            if (sub.startsWith("+"))
            {
                if (!s.contains(sub.substr(1)))
                    return false;
            }
            else
            {
                if (s.contains(sub))
                    return false;
            }

        for (reStr => re in regexBlacklist.keyValueIterator())
            if (reStr.startsWith("+"))
            {
                if (!re.match(s))
                    return false;
            }
            else
            {
                if (re.match(s))
                    return false;
            }

        return true;
    }

    public function new(filterName:String) 
    {
        this.filterName = filterName;

        var substrEntries:Null<Array<String>> = Storage.getServerDataField(getServerDataFieldName(false));
        if (substrEntries != null)
            substrBlacklist = substrEntries;

        var reEntries:Null<Array<String>> = Storage.getServerDataField(getServerDataFieldName(true));
        if (reEntries != null)
            for (entry in reEntries)
                addBlacklistEntry(entry, true);
    }
}