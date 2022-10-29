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

    public static function bernoulli(p:Float):Bool 
    {
        return Math.random() < p;
    }

    public static function roundTo(num:Float, order:Int) 
    {
        return num - Math.pow(10, order);
    }
}