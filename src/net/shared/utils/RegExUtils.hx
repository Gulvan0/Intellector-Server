package net.shared.utils;

class RegExUtils 
{
    public static function allMatches(str:String, regex:EReg, group:Int = 0):Array<String>
    {
        var matches:Array<String> = [];

        var matchPos:Int = 0;
        while (regex.matchSub(str, matchPos))
        {
            matches.push(regex.matched(group));
            
            var mpos = regex.matchedPos();
            matchPos = mpos.pos + mpos.len;
        }

        return matches;
    }    
}