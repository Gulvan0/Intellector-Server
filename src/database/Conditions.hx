package database;

class Conditions 
{
    public static function equals(column:String, value:Dynamic):String
    {
        return '$column = ${Utils.toMySQLValue(value)}';
    }    
}