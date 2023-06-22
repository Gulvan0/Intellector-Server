package config;

import sys.ssl.Key;
import sys.ssl.Certificate;

class ValueConverters 
{
    public static function asInt(value:Dynamic):Int
    {
        return value;
    }

    public static function asFloat(value:Dynamic):Float
    {
        return value;
    }

    public static function asString(value:Dynamic):String
    {
        return value;
    }

    public static function asBool(value:Dynamic):Bool
    {
        return value;
    }

    public static function asCertificate(value:Dynamic):Certificate
    {
        return Certificate.loadFile(value);
    }

    public static function asKey(value:Dynamic):Key
    {
        return Key.loadFile(value);
    }
}