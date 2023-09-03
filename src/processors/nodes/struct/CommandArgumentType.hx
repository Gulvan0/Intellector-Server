package processors.nodes.struct;

import net.shared.utils.TimeInterval;
import net.shared.utils.UnixTimestamp;

enum CommandArgumentType 
{
    TInt(defaultValue:Null<Int>);
    TFloat(defaultValue:Null<Float>);
    TBool(defaultValue:Null<Bool>);
    TString(maxChars:Int, defaultValue:Null<String>);
    TLogin(defaultValue:Null<String>);
    TTimestamp(defaultValue:Null<UnixTimestamp>);
    TInterval(defaultValue:Null<TimeInterval>);
    TEnum<T>(e:Enum<T>, defaultValue:Null<T>);
}