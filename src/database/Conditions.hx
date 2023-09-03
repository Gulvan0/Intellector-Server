package database;

class Conditions 
{
    public static function equals(column:String, value:Dynamic):String
    {
        return '$column = ${Utils.toMySQLValue(value)}';
    }
    
    public static function and(conditions:Array<String>):String 
    {
        return "(" + conditions.join(") AND (") + ")";
    }
    
    public static function or(conditions:Array<String>):String 
    {
        return "(" + conditions.join(") OR (") + ")";
    }
}