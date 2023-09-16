package database;

import net.shared.variation.VariationPath;
import config.Config;
import net.shared.EloValue;
import net.shared.dataobj.StudyPublicity;
import net.shared.dataobj.UserRole;
import net.shared.board.HexCoords;
import net.shared.board.RawPly;
import net.shared.PieceType;
import net.shared.dataobj.OfferAction;
import net.shared.dataobj.OfferKind;
import net.shared.Outcome;
import net.shared.Outcome.DrawishOutcomeType;
import net.shared.utils.PlayerRef;
import net.shared.dataobj.ChallengeType;
import net.shared.board.Situation;
import net.shared.TimeControl;
import net.shared.TimeControlType;
import net.shared.utils.UnixTimestamp;
import net.shared.PieceColor;

using hx.strings.Strings;

abstract ResultRow(Dynamic) from Dynamic
{
    public function isNotNull(columnName:String):Bool
    {
        return Reflect.field(this, columnName) != null;
    }

    public function getString(columnName:String):Null<String> 
    {
        return Reflect.field(this, columnName);
    }

    public function getInt(columnName:String):Null<Int> 
    {
        return Reflect.field(this, columnName);
    }

    public function getFloat(columnName:String):Null<Float> 
    {
        return Reflect.field(this, columnName);
    }

    public function getBool(columnName:String):Null<Bool> 
    {
        return Reflect.field(this, columnName);
    }

    public function getPlayerRef(columnName:String):Null<PlayerRef> 
    {
        return Reflect.field(this, columnName);
    }

    public function getTimestamp(columnName:String):Null<UnixTimestamp>
    {
        var field:Null<Date> = Reflect.field(this, columnName);

        if (field == null)
            return null;
        else
            return UnixTimestamp.fromDate(field);
    }

    public function getPieceColor(columnName:String):Null<PieceColor> 
    {
        var field:Null<String> = Reflect.field(this, columnName);

        if (field == null)
            return null;
        else if (field == "white")
            return White;
        else if (field == "black")
            return Black;
        else
            return null;
    }

    public function getTimeControlType(columnName:String):Null<TimeControlType>
    {
        var field:Null<String> = Reflect.field(this, columnName);

        if (field == null)
            return null;
        else
            return TimeControlType.createByName(field.toUpperCaseFirstChar());
    }

    public function getFischerTimeControl(startSecsColumnName:String, bonusSecsColumnName:String):Null<TimeControl>
    {
        var startSecs:Null<Int> = Reflect.field(this, startSecsColumnName);
        var bonusSecs:Null<Int> = Reflect.field(this, bonusSecsColumnName);

        if (startSecs == null || bonusSecs == null)
            return null;
        else
            return new TimeControl(startSecs, bonusSecs);
    }

    public function getSituation(sipColumnName:String):Null<Situation>
    {
        var field:Null<String> = Reflect.field(this, sipColumnName);

        if (field == null)
            return null;
        else
            return Situation.deserialize(field);
    }

    public function getChallengeType(typeColumnName:String, calleeColumnName:String):Null<ChallengeType>
    {
        var challengeType:Null<String> = Reflect.field(this, typeColumnName);
        var challengeCalleeRef:Null<PlayerRef> = getPlayerRef(calleeColumnName);

        if (challengeType == null)
            return null;
        else if (challengeType == "public")
            return Public;
        else if (challengeType == "link_only")
            return ByLink;
        else if (challengeType != "direct")
            throw 'Unknown challenge type: $challengeType';
        else if (challengeCalleeRef == null)
            throw "Empty callee ref for direct challenge type";
        else
            return Direct(challengeCalleeRef);
    }

    public function getOutcome(outcomeTypeColumnName:String, winnerColorColumnName:String):Null<Outcome>
    {
        var outcomeType:Null<String> = Reflect.field(this, outcomeTypeColumnName);
        var winnerColor:Null<PieceColor> = getPieceColor(winnerColorColumnName);

        if (outcomeType == null)
            return null;
        if (winnerColor == null)
            for (drawishOutcome in DrawishOutcomeType.createAll())
                if (drawishOutcome.getName().toLowerCase() == outcomeType.filterChars(char -> char.isAsciiAlpha()))
                    return Drawish(drawishOutcome);
        else
            for (decisiveOutcome in DecisiveOutcomeType.createAll())
                if (decisiveOutcome.getName().toLowerCase() == outcomeType.filterChars(char -> char.isAsciiAlpha()))
                    return Decisive(decisiveOutcome, winnerColor);

        throw 'Failed to parse outcome: Type = $outcomeType, WinnerColor = $winnerColor';
    }

    public function getOfferKind(columnName:String):Null<OfferKind> 
    {
        var field:Null<String> = Reflect.field(this, columnName);

        if (field == null)
            return null;
        else
            return OfferKind.createByName(field.toUpperCaseFirstChar());
    }

    public function getOfferAction(columnName:String):Null<OfferAction> 
    {
        var field:Null<String> = Reflect.field(this, columnName);

        if (field == null)
            return null;
        else
            return OfferAction.createByName(field.toUpperCaseFirstChar());
    }

    public function getPieceType(columnName:String):Null<PieceType> 
    {
        var field:Null<String> = Reflect.field(this, columnName);

        if (field == null)
            return null;
        else
            return PieceType.createByName(field.toUpperCaseFirstChar());
    }

    public function getPly(fromScalarCoordColumnName:String, toScalarCoordColumnName:String, morphIntoColumnName:String):Null<RawPly> 
    {
        var fromCoord:Null<Int> = Reflect.field(this, fromScalarCoordColumnName);
        var toCoord:Null<Int> = Reflect.field(this, toScalarCoordColumnName);
        var morphInto:Null<PieceType> = getPieceType(morphIntoColumnName);

        if (fromCoord == null && toCoord == null && morphInto == null)
            return null;
        else if (fromCoord == null || toCoord == null)
            throw 'Invalid combination of null values for ply columns: From = $fromCoord, To = $toCoord, MorphInto = $morphInto';
        else
            return RawPly.construct(HexCoords.fromScalarCoord(fromCoord), HexCoords.fromScalarCoord(toCoord), morphInto);
    }

    public function getUserRole(columnName:String):Null<UserRole>
    {
        var field:Null<String> = Reflect.field(this, columnName);

        if (field == null)
            return null;

        for (role in UserRole.createAll())
            if (role.getName().toLowerCase() == field.filterChars(char -> char.isAsciiAlpha()))
                return role;

        throw 'Unknown UserRole: $field';
    }

    public function getStudyPublicity(columnName:String):Null<StudyPublicity>
    {
        var field:Null<String> = Reflect.field(this, columnName);

        if (field == null)
            return null;

        for (publicity in StudyPublicity.createAll())
            if (publicity.getName().toLowerCase() == field.filterChars(char -> char.isAsciiAlpha()))
                return publicity;

        throw 'Unknown StudyPublicity: $field';
    }

    public function getElo(eloColumnName:String, relevantGamesCountColumnName:String):Null<EloValue>
    {
        var elo:Null<Int> = Reflect.field(this, eloColumnName);
        var relevantGamesCount:Null<Int> = Reflect.field(this, relevantGamesCountColumnName);

        if (elo == null && relevantGamesCount == null)
            return null;
        else if (relevantGamesCount == null)
            throw 'Invalid combination of null values for elo columns: Elo = $elo, RelevantGamesCount = $relevantGamesCount';
        else if (relevantGamesCount == 0)
            return None;
        else if (relevantGamesCount < Config.config.calibrationGamesCount)
            return Provisional(elo);
        else
            return Normal(elo);
    }

    public function getVariationPath(joinedPathColumnName:String):Null<VariationPath>
    {
        var joinedPath:Null<String> = Reflect.field(this, joinedPathColumnName);

        if (joinedPath == null)
            return null;
        else
            return VariationPath.deserialize(joinedPath);
    }
}