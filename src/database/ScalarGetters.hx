package database;

import sys.db.ResultSet;

class ScalarGetters 
{
    public static function getScalarInt(set:ResultSet):Null<Int> 
    {
        if (set.hasNext())
            return set.getIntResult(0);
        else
            return null;
    }
    
    public static function getScalarString(set:ResultSet):Null<String> 
    {
        if (set.hasNext())
            return set.getResult(0);
        else
            return null;
    } 
    
    public static function getScalarFloat(set:ResultSet):Null<Float> 
    {
        if (set.hasNext())
            return set.getFloatResult(0);
        else
            return null;
    }      
}