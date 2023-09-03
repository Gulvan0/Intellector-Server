package net.shared.utils;

import hx.strings.Strings;

abstract TimeInterval(Float) from Float to Float
{
    public static inline final YEAR:TimeInterval = new TimeInterval(31536000);
    public static inline final MONTH:TimeInterval = new TimeInterval(2592000);
    public static inline final WEEK:TimeInterval = new TimeInterval(604800);
    public static inline final DAY:TimeInterval = new TimeInterval(86400);
    public static inline final HOUR:TimeInterval = new TimeInterval(3600);
    public static inline final MINUTE:TimeInterval = new TimeInterval(60);
    public static inline final SECOND:TimeInterval = new TimeInterval(1);
    public static inline final MS:TimeInterval = new TimeInterval(0.001);

    public static inline function zero():TimeInterval
    {
        return 0;
    }

    public static inline function milliseconds(amount:Float):TimeInterval
    {
        return MS * amount;
    }

    public static inline function seconds(amount:Float):TimeInterval
    {
        return SECOND * amount;
    }

    public static inline function minutes(amount:Float):TimeInterval
    {
        return MINUTE * amount;
    }

    public static inline function hours(amount:Float):TimeInterval
    {
        return HOUR * amount;
    }

    public static inline function days(amount:Float):TimeInterval
    {
        return DAY * amount;
    }

    public static inline function weeks(amount:Float):TimeInterval
    {
        return WEEK * amount;
    }

    public static inline function months(amount:Float):TimeInterval
    {
        return MONTH * amount;
    }

    public static inline function years(amount:Float):TimeInterval
    {
        return YEAR * amount;
    }

    public static inline function build(ms:Float, ?secsCnt:Int = 0, ?minsCnt:Int = 0, ?hoursCnt:Int = 0, ?daysCnt:Int = 0, ?monthsCnt:Int = 0, ?yearsCnt:Int = 0):TimeInterval
    {
        return milliseconds(ms) + seconds(secsCnt) + minutes(minsCnt) + hours(hoursCnt) + days(daysCnt) + months(monthsCnt) + years(yearsCnt);
    }

    public static inline function buildWeeks(weeksCnt:Int, ?monthsCnt:Int = 0, ?yearsCnt:Int = 0):TimeInterval
    {
        return weeks(weeksCnt) + months(monthsCnt) + years(yearsCnt);
    }

    public static function fromString(str:String):TimeInterval
    {
        var negative:Bool = false;

        if (str.charAt(0) == '-')
        {
            negative = true;
            str = str.substr(1);
        }

        var totalInterval:TimeInterval = zero();
        var i:Int = 0;
        var currentAmount:String = "";

        while (i < str.length)
        {
            var char:String = str.charAt(i);

            if (Strings.isDigits(char) || char == '.')
                currentAmount += char;
            else
            {
                switch char 
                {
                    case "s": 
                        totalInterval += seconds(Std.parseFloat(currentAmount));
                    case "m": 
                        totalInterval += minutes(Std.parseFloat(currentAmount));
                    case "h": 
                        totalInterval += hours(Std.parseFloat(currentAmount));
                    case "D": 
                        totalInterval += days(Std.parseFloat(currentAmount));
                    case "W": 
                        totalInterval += weeks(Std.parseFloat(currentAmount));
                    case "M": 
                        totalInterval += months(Std.parseFloat(currentAmount));
                    case "Y":
                        totalInterval += years(Std.parseFloat(currentAmount));
                    default:
                        return null;
                }

                currentAmount = "";
            }

            i++;
        }

        totalInterval += milliseconds(Std.parseFloat(currentAmount));

        return negative? -totalInterval : totalInterval;
    }

    @:op(A + B) public function plus(anotherInterval:TimeInterval):TimeInterval;
    @:op(A - B) public function minus(anotherInterval:TimeInterval):TimeInterval;
    @:op(A * B) public function times(mul:Float):TimeInterval;
    @:op(A / B) public function dividedBy(divisor:Float):TimeInterval;
    @:op(-A) public function inverse():TimeInterval;

    public inline function isNegative():Bool
    {
        return this < 0;
    }
    
    public inline function getSeconds():Float
    {
        return this;
    }

    public inline function getMilliseconds():Float
    {
        return getSeconds() / MS.getSeconds();
    }

    public inline function getMinutes():Float
    {
        return getSeconds() / MINUTE.getSeconds();
    }

    public inline function getHours():Float
    {
        return getSeconds() / HOUR.getSeconds();
    }

    public inline function getDays():Float
    {
        return getSeconds() / DAY.getSeconds();
    }

    public inline function getWeeks():Float
    {
        return getSeconds() / WEEK.getSeconds();
    }

    public inline function getMonths():Float
    {
        return getSeconds() / MONTH.getSeconds();
    }

    public inline function getYears():Float
    {
        return getSeconds() / YEAR.getSeconds();
    }

    private function new(secs:Float)
    {
        this = secs;
    }
}