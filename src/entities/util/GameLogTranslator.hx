package entities.util;

import struct.TimeControl;
import struct.Situation;
import net.shared.EloValue.deserialize;
import net.shared.PieceType;
import struct.HexCoords;
import net.shared.PieceColor;
import entities.util.GameLogEntry.Event;
import net.shared.Outcome;
import net.shared.Outcome.DrawishOutcomeType;
import net.shared.Outcome.DecisiveOutcomeType;
import net.shared.PieceColor.letter;

using StringTools;

class GameLogTranslator 
{
    private static inline final separator:String = ";";
    
    private static function encodeDecisiveOutcome(outcome:DecisiveOutcomeType):String 
    {
        return switch outcome 
        {
            case Mate: "mat";
            case Breakthrough: "bre";
            case Timeout: "tim";
            case Resign: "res";
            case Abandon: "aba";
        }
    }
    
    private static function encodeDrawishOutcome(outcome:DrawishOutcomeType):String 
    {
        return switch outcome 
        {
            case DrawAgreement: "agr";
            case Repetition: "rep";
            case NoProgress: "100";
            case Abort: "abo";
        }
    }
    
    private static function decodeDecisiveOutcome(str:String):DecisiveOutcomeType 
    {
        switch str 
        {
            case "mat": 
                return Mate;
            case "bre":
                return Breakthrough; 
            case "res": 
                return Resign;
            case "tim": 
                return Timeout;
            case "aba": 
                return Abandon;
            default:
                throw 'Cannot decode decisive outcome: $str';
        }
    }
    
    private static function decodeDrawishOutcome(str:String):DrawishOutcomeType 
    {
        switch str 
        {
            case "rep":
                return Repetition;
            case "100":
                return NoProgress;
            case "agr":
                return DrawAgreement;
            case "abo":
                return Abort; 
            default:
                throw 'Cannot decode drawish outcome: $str';
        }
    }

    private static function encodeEvent(event:Event):String 
    {
        return switch event 
        {
            case PlayerDisconnected(color): "dcn" + letter(color);
            case PlayerReconnected(color): "rcn" + letter(color);
            case DrawOffered(offerOwnerColor): "dof" + letter(offerOwnerColor);
            case DrawCanceled(offerOwnerColor): "dca" + letter(offerOwnerColor);
            case DrawAccepted(offerReceiverColor): "dac" + letter(offerReceiverColor);
            case DrawDeclined(offerReceiverColor): "dde" + letter(offerReceiverColor);
            case TakebackOffered(offerOwnerColor): "tof" + letter(offerOwnerColor);
            case TakebackCanceled(offerOwnerColor): "tca" + letter(offerOwnerColor);
            case TakebackAccepted(offerReceiverColor): "tac" + letter(offerReceiverColor);
            case TakebackDeclined(offerReceiverColor): "tde" + letter(offerReceiverColor);
            case TimeAdded(bonusTimeReceiverColor): "tad" + letter(bonusTimeReceiverColor);
        }
    }

    private static function decodeEvent(args:Array<String>):Event
    {
        if (args.length != 2)
            throw 'Cannot decode game event (wrong number of entry args): $args';

        var color:PieceColor = colorByLetter(args[1]);

        switch args[0]
        {
            case "dcn":
                return PlayerDisconnected(color);
            case "rcn":
                return PlayerReconnected(color);
            case "dof":
                return DrawOffered(color);
            case "dca":
                return DrawCanceled(color);
            case "dac":
                return DrawAccepted(color);
            case "dde":
                return DrawDeclined(color);
            case "tof":
                return TakebackOffered(color);
            case "tca":
                return TakebackCanceled(color); 
            case "tac":
                return TakebackAccepted(color);
            case "tde":
                return TakebackDeclined(color);
            case "tad":
                return TimeAdded(color);
            default:
                throw 'Cannot decode game event: $args';
        }
    }

    public static function parse(log:String):Array<GameLogEntry> 
    {
        var a:Array<GameLogEntry> = [];

        for (encodedEntry in split(log))
        {
            var entry:GameLogEntry;

            if (encodedEntry.startsWith("#"))
            {
                var separatorPos:Int = encodedEntry.indexOf('|');
                entry = parseSpecialEntry(encodedEntry.substring(1, separatorPos), encodedEntry.substring(separatorPos + 1));
            }
            else
                entry = parseNormalEntry(encodedEntry);

            a.push(entry);
        }
            
        return a;
    }

    private static function parseNormalEntry(encodedEntry:String):GameLogEntry
    {
        var splitted:Array<String> = encodedEntry.split("/");

        var from:HexCoords = new HexCoords(Std.parseInt(splitted[0].charAt(0)), Std.parseInt(splitted[0].charAt(1)));
        var to:HexCoords = new HexCoords(Std.parseInt(splitted[0].charAt(2)), Std.parseInt(splitted[0].charAt(3)));
        var morphInto:Null<PieceType> = splitted[0].length > 4? PieceType.createByName(splitted[0].substr(4)) : null;

        if (splitted.length == 3)
            return Move(from, to, morphInto, Std.parseInt(splitted[1]), Std.parseInt(splitted[2]));
        else
            return Move(from, to, morphInto, null, null);
    }

    private static function parseSpecialEntry(typeCode:String, body:String):GameLogEntry 
    {
        var args:Array<String> = body.split("/");
        switch typeCode
        {
            case "P":
                var playerRefs:Array<String> = args[0].split(":");
                return Players(playerRefs[0], playerRefs[1]);
            case "e":
                return Elo(deserialize(args[0]), deserialize(args[1]));
            case "D":
                return DateTime(Date.fromTime(Std.parseInt(args[0]) * 1000));
            case "L":
                return MsLeft(Std.parseInt(args[0]), Std.parseInt(args[1]));
            case "S":
                return CustomStartingSituation(Situation.deserialize(args[0]));
            case "T":
                return TimeControl(new TimeControl(Std.parseInt(args[0]), Std.parseInt(args[1])));
            case "C":
                return PlayerMessage(colorByLetter(args[0]), args[1]);
            case "R":
                if (args[0] == "d")
                    return Result(Drawish(decodeDrawishOutcome(args[1])));
                else
                    return Result(Decisive(decodeDecisiveOutcome(args[1]), colorByLetter(args[0])));
            case "E":
                return Event(decodeEvent(args));
            default:
                throw 'Failed to parse special entry: unknown code $typeCode';
        }        
    }

    public static function encode(entry:GameLogEntry):String 
    {
        switch entry 
        {
            case Move(from, to, morphInto, whiteMsLeft, blackMsLeft):
                var base:String = '${from.i}${from.j}${to.i}${to.j}';
                if (morphInto != null)
                    base += morphInto.getName();
                if (whiteMsLeft != null && blackMsLeft != null)
                    base += '/$whiteMsLeft/$blackMsLeft';
                return base;
            case Players(whiteRef, blackRef):
                return '#P|$whiteRef:$blackRef';
            case Elo(whiteElo, blackElo):
                return '#e|$whiteElo/$blackElo';
            case DateTime(ts):
                return '#D|${Math.floor(ts.getTime() / 1000)}';
            case MsLeft(whiteMs, blackMs):
                return '#L|$whiteMs/$blackMs';
            case CustomStartingSituation(situation):
                return '#S|${situation.serialize()}';
            case TimeControl(timeControl):
                return '#T|${timeControl.startSecs}/${timeControl.incrementSecs}';
            case PlayerMessage(authorColor, messageText):
                return '#C|${letter(authorColor)}/$messageText';
            case Result(Decisive(type, winnerColor)):
                return '#R|${letter(winnerColor)}/${encodeDecisiveOutcome(type)}';
            case Result(Drawish(type)):
                return '#R|d/${encodeDrawishOutcome(type)}';
            case Event(event):
                return '#E|${encodeEvent(event)}';
        }
    }

    public static function split(log:String):Array<String>
    {
        return log.split(separator).map(StringTools.trim);
    }

    public static function join(encodedEntries:Array<String>):String 
    {
        return encodedEntries.join(separator + '\n');
    }

    public static function concat(log:String, newEntry:GameLogEntry):String 
    {
        return log + encode(newEntry) + separator + '\n';
    }

    public static function fromEntries(entries:Array<GameLogEntry>):String
    {
        return join(entries.map(encode));
    }
}