package utils;

class MathUtils
{
    public static function randomInt(from:Int, to:Int) 
    {
        return from + Math.floor(Math.random() * (to - from + 1));
    }
}