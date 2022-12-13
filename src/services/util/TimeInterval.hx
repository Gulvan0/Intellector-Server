package services.util;

using StringTools;

abstract TimeInterval(String) from String to String
{
    public function isNegative():Bool
    {
        return this.charCodeAt(0) == "-".code;
    }

    public function toSeconds():Float
    {
        var totalSecsInterval:Float = 0;

        var negative:Bool = isNegative();
        var thisStr:String = negative? this.substr(1).toLowerCase() : this.toLowerCase();
        var number:String = "";

        for (i in 0...thisStr.length)
        {
            var code:Int = thisStr.charCodeAt(i);
            var dotPassed:Bool = false;
            switch code
            {
                case "d".code:
                    totalSecsInterval += Std.parseFloat(number) * UnixSecs.Day;
                    number = "";
                    dotPassed = false;
                case "h".code:
                    totalSecsInterval += Std.parseFloat(number) * UnixSecs.Hour;
                    number = "";
                    dotPassed = false;
                case "m".code:
                    totalSecsInterval += Std.parseFloat(number) * UnixSecs.Minute;
                    number = "";
                    dotPassed = false;
                case "s".code:
                    totalSecsInterval += Std.parseFloat(number) * UnixSecs.Second;
                    number = "";
                    dotPassed = false;
                case ".".code:
                    if (!dotPassed)
                        number += ".";
                    dotPassed = true;
                default:
                    if (code >= "0".code && code <= "9".code)
                        number += String.fromCharCode(code);
            }
        }

        return negative? -totalSecsInterval : totalSecsInterval;
    }

    public function toMilliseconds():Float
    {
        return toSeconds() * 1000;
    }

    public function add(date:Date):Date 
    {
        return Date.fromTime(date.getTime() + toMilliseconds());
    }
}