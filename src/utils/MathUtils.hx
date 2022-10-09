package utils;

class MathUtils
{
    public static function maxInt(a:Int, b:Int):Int
    {
        return Std.int(Math.max(a, b));
    }

    public static function randomInt(from:Int, to:Int) 
    {
        return from + Math.floor(Math.random() * (to - from + 1));
    }
}