package processors.nodes.struct;

class CommandArgument 
{
    public final name:String;
    public final type:CommandArgumentType;
    public final required:Bool;

    public function describe():String 
    {
        var typeStr:String;
        var defaultValueStr:String;

        switch type 
        {
            case TInt(defaultValue):
                typeStr = "Integer";
                defaultValueStr = Std.string(defaultValue);
            case TFloat(defaultValue):
                typeStr = "Float";
                defaultValueStr = Std.string(defaultValue);
            case TBool(defaultValue):
                typeStr = "Bool";
                defaultValueStr = Std.string(defaultValue);
            case TString(maxChars, defaultValue):
                typeStr = "String";
                defaultValueStr = defaultValue;
            case TLogin(defaultValue):
                typeStr = "Login";
                defaultValueStr = defaultValue;
            case TTimestamp(defaultValue):
                typeStr = "Timestamp";
                defaultValueStr = defaultValue.format(DashDelimitedDayWithTJoinedTime);
            case TInterval(defaultValue):
                typeStr = "Time Interval";
                defaultValueStr = '${defaultValue.getSeconds()} secs';
            case TEnum(e, defaultValue):
                typeStr = e.getName();
                defaultValueStr = Std.string(defaultValue);
        }

        return 'Name: $name\nType: $typeStr\nRequired: $required\nDefault Value: $defaultValueStr';
    }

    public function obtainValue(strValue:Null<String>):Dynamic
    {
        return switch type 
        {
            case TInt(defaultValue):
                strValue != null? Std.parseInt(strValue) : defaultValue;
            case TFloat(defaultValue):
                strValue != null? Std.parseFloat(strValue) : defaultValue;
            case TBool(defaultValue):
                strValue != null? ["true", "t", "1"].contains(strValue.toLowerCase()) : defaultValue;
            case TString(maxChars, defaultValue):
                strValue != null? strValue.substr(0, maxChars) : defaultValue;
            case TLogin(defaultValue):
                strValue != null? strValue.toLowerCase() : defaultValue;
            case TTimestamp(defaultValue):
                strValue != null? UnixTimestamp.fromDate(Date.fromString(StringTools.replace(strValue, "T", " "))) : defaultValue;
            case TInterval(defaultValue):
                strValue != null? TimeInterval.fromString(strValue) : defaultValue;
            case TEnum(e, defaultValue):
                strValue != null? e.createByName(strValue) : defaultValue;
        }
    }

    public function allowsEmptyString():Bool
    {
        return type.match(TString(_, _) | TLogin(_));
    }

    public function new(name:String, type:CommandArgumentType, ?required:Bool = false) 
    {
        this.name = name;
        this.type = type;
        this.required = required;
    }
}