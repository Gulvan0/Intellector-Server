package utils.ds;

class ArrayTools 
{
    public static function last<T>(a:Array<T>):Null<T>
    {
        return a.length > 0? a[a.length - 1] : null;
    } 
    
    public static function intersects<T>(a1:Array<T>, a2:Array<T>):Bool
    {
        for (el in a1)
            if (a2.contains(el))
                return true;
        return false;
    }
}