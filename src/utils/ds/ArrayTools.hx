package utils.ds;

class ArrayTools 
{
    public static function last<T>(a:Array<T>):Null<T>
    {
        return a.length > 0? a[a.length - 1] : null;
    }    
}