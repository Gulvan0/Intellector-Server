package database;

import database.special_values.RawInsert;
import net.shared.board.Situation;
import net.shared.dataobj.StudyPublicity;
import net.shared.dataobj.UserRole;
import net.shared.PieceType;
import net.shared.dataobj.OfferDirection;
import net.shared.dataobj.OfferKind;
import net.shared.dataobj.OfferAction;
import net.shared.Outcome;
import database.special_values.ChallengeAcceptingSide;
import database.special_values.Timestamp;
import net.shared.TimeControlType;
import net.shared.dataobj.ChallengeType;
import net.shared.PieceColor;

using hx.strings.Strings;

class Utils 
{
    private static function quote(value:String):String 
    {
        return "'" + value + "'";
    } 

    public static function entityNameToDDLResourceName(entityName:String):String 
    {
        var parts:Array<String> = entityName.split('.');
        var schema:String = parts[0];
        var name:String = parts[1];

        return 'sql/ddl/$schema/$name.sql';
    }

    public static function toMySQLValuesRow(a:Array<Dynamic>):String
    {
        return "(" + a.map(toMySQLValue).join(", ") + ")";
    }

    public static function toMySQLValue(val:Dynamic):String
    {
        if (val == null)
            return "NULL";
        else if (Std.isOfType(val, Float))
            return Std.string(val);
        else if (Std.isOfType(val, String))
            return quote(val);
        else if (Std.isOfType(val, Date))
            return quote(cast(val, Date).toString());
        else if (Std.isOfType(val, Bool))
            return cast(val, Bool)? "1" : "0";
        else if (Std.isOfType(val, RawInsert))
            return unwrapRawInsert(val);
        else if (Std.isOfType(val, Timestamp))
            return convertTimestamp(val);
        else if (Std.isOfType(val, Situation))
            return convertSituation(val);
        else if (Std.isOfType(val, ChallengeAcceptingSide))
            return convertAcceptingSide(val);
        else if (Std.isOfType(val, ChallengeType))
            return convertStandardEnum(val);
        else if (Std.isOfType(val, OfferKind))
            return convertStandardEnum(val);
        else if (Std.isOfType(val, OfferAction))
            return convertStandardEnum(val);
        else if (Std.isOfType(val, PieceColor))
            return convertStandardEnum(val);
        else if (Std.isOfType(val, PieceType))
            return convertStandardEnum(val);
        else if (Std.isOfType(val, UserRole))
            return convertStandardEnum(val);
        else if (Std.isOfType(val, StudyPublicity))
            return convertStandardEnum(val);
        else
            throw 'Can\'t convert value to MySQL type: $val';
    }

    private static function unwrapRawInsert(insert:RawInsert):String
    {
        return switch insert 
        {
            case Raw(insertedQueryPart):
                insertedQueryPart;
        }
    }

    private static function convertStandardEnum(val:EnumValue):String 
    {
        var strValue:String = val.getName().toLowerUnderscore();

        return quote(strValue);
    }

    private static function convertTimestamp(val:Timestamp):String 
    {
        return switch val
        {
            case CurrentTimestamp:
                "CURRENT_TIMESTAMP";
            case ArbitraryTimestamp(a):
                quote(a.format(DashDelimitedDayWithSeparateTime));
        }
    }

    private static function convertSituation(val:Situation):String 
    {
        var strValue:String = val.serialize();

        return quote(strValue);
    }

    private static function convertAcceptingSide(val:ChallengeAcceptingSide):String
    {
        var strValue:String = switch val 
        {
            case Specified(side):
                side.getName().toLowerUnderscore();
            case Random:
                "random";
        }

        return quote(strValue);
    }

    public static function extractChallengeType(val:ChallengeType):String 
    {
        return switch val 
        {
            case Public:
                "public";
            case ByLink:
                "link_only";
            case Direct(calleeRef):
                "direct";
        }
    }

    public static function extractChallengeCallee(val:ChallengeType):Null<String>
    {
        return switch val 
        {
            case Direct(calleeRef):
                calleeRef;
            default:
                null;
        }
    }

    public static function extractOutcomeType(outcome:Outcome):String
    {
        return switch outcome 
        {
            case Decisive(type, _):
                type.getName().toLowerUnderscore();
            case Drawish(type):
                type.getName().toLowerUnderscore();
        }
    }

    public static function extractWinnerColor(outcome:Outcome):Null<String>
    {
        return switch outcome 
        {
            case Decisive(_, winnerColor):
                winnerColor;
            case Drawish(_):
                null;
        }
    }
}