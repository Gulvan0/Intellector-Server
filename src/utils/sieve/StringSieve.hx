package utils.sieve;

import haxe.Unserializer;
import haxe.Serializer;
using hx.strings.Strings;

class StringSieve 
{
    private var filters:Map<String, Filter> = [];

    public function getFirstBlockingFilter(str:String):Null<String> 
    {
        for (name => filter in filters.keyValueIterator())
            switch filter 
            {
                case Substring(sub, containingRemoved):
                    if (str.contains(sub) == containingRemoved)
                        return name;
                case RegExp(ereg, _, _, matchingRemoved):
                    if (ereg.match(sub) == matchingRemoved)
                        return name;
            }

        return null;
    }

    public function checkPass(str:String):Bool 
    {
        return getFirstBlockingFilter(str) == null;
    }   

    private function describeFilterInstance(filter:Filter):String
    {
        switch filter 
        {
            case Substring(sub, containingRemoved):
                if (containingRemoved)
                    return 'Contains $sub';
                else
                    return 'Does not contain $sub';
            case RegExp(ereg, rawExpression, rawFlags, matchingRemoved):
                if (matchingRemoved)
                    return 'Matches ~/$rawExpression/$rawFlags';
                else
                    return 'Does not match ~/$rawExpression/$rawFlags';
        }
    }

    public function describeFilter(name:String):String
    {
        var filter:Null<Filter> = filters.get(name);

        if (filter == null)
            return "Filter not found";
        else
            return describeFilterInstance(filter);
    }

    public function listFilters():Array<String>
    {
        var a:Array<String> = [];

        for (name => filter in filters.keyValueIterator())
            a.push('$name: ${describeFilterInstance(filter)}');

        return a;
    }

    public function add(name:String, filter:Filter) 
    {
        if (!filters.exists(name))
            filters.set(name, filter);
    }

    public function remove(name:String) 
    {
        filters.remove(name);
    }

    public function dumps():String
    {
        var stringMap:Map<String, String> = [for (name => filter in filters.keyValueIterator()) name => filterToString(filter)];
        return Serializer.run(stringMap);
    }

    public function loads(str:String)
    {
        filters = Unserializer.run(str);
    }

    private function filterToString(filter:Filter):String
    {
        switch filter 
        {
            case Substring(sub, containingRemoved):
                return "s" + (containingRemoved? "t" : "f") + sub;
            case RegExp(ereg, rawExpression, rawFlags, matchingRemoved):
                return "r" + (matchingRemoved? "t" : "f") + rawFlags + "|" + rawExpression;
        }
    }

    private function filterFromString(str:String):Filter 
    {
        if (str.charAt(0) == "s")
            return Substring(str.substr(2), str.charAt(1) == "t");
        else
        {
            var parts:Array<String> = str.split8("|", 2);
            var rawExpression:String = parts[1];
            var rawFlags:String = parts[0].substr(2);
            var matchingRemoved:Bool = parts[0].charAt(1) == "t";
            return RegExp(new EReg(rawExpression, rawFlags), rawExpression, rawFlags, matchingRemoved);
        }
    }
    
    public function new(?filterDump:String) 
    {
        if (filterDump != null)
            loads(filterDump);
    }
}