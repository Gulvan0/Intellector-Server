package database.endpoints;

import processors.nodes.Subscriptions;
import net.shared.dataobj.GameModelData;
import database.returned.GetOpenChallengeByIDResult;
import net.shared.TimeControl;
import net.shared.PieceColor;
import database.special_values.ChallengeAcceptingSide;
import net.shared.dataobj.ChallengeData;
import net.shared.dataobj.ChallengeParams;

class Challenge
{
    public static function create(data:ChallengeData):Int
    {
        var timeControl:TimeControl = data.params.timeControl;

        var challengeRow:Array<Dynamic> = [
            null,
            data.ownerRef,
            Utils.extractChallengeType(data.params.type),
            Utils.extractChallengeCallee(data.params.type),
            timeControl.getType(),
            constructAcceptingSide(data),
            data.params.customStartingSituation,
            data.params.rated,
            true,
            null
        ];

        var result:QueryExecutionResult = Database.instance.insertRow("challenge.challenge", challengeRow, true);

        var challengeID:Int = result.lastID;

        if (!timeControl.isCorrespondence())
            Database.instance.insertRow("challenge.fischer_time_control", [challengeID, timeControl.startSecs, timeControl.incrementSecs], false);

        return challengeID;
    }

    public static function deactivate(challengeID:Int, resultingGameID:Null<Int>) 
    {
        var updates:Map<String, Dynamic> = [
            "active" => false,
            "resulting_game_id" => resultingGameID
        ];
        var conditions:Array<String> = [
            Conditions.equals("id", challengeID)
        ];

        Database.instance.update("challenge.challenge", updates, conditions);
    }

    public static function getActiveIncoming(calleeRef:PlayerRef):Array<ChallengeData>
    {
        var rows:Array<ResultRow> = Database.instance.simpleRows(GetActiveIncomingChallenges, ["callee_ref" => calleeRef]);

        return parseRowsAsChallenges(rows);
    }

    public static function getActivePublic():Array<ChallengeData>
    {
        var rows:Array<ResultRow> = Database.instance.simpleRows(GetActivePublicChallenges);

        return parseRowsAsChallenges(rows);
    }

    public static function getOpenChallengeByID(challengeID:Int):GetOpenChallengeByIDResult
    {
        var rows:Array<ResultRow> = Database.instance.simpleRows(GetOpenChallengeByID, ["challenge_id" => challengeID]);

        if (rows.length == 0)
            return Nonexistent;
        else if (rows.length > 1)
            Logging.error("e:Challenge.getOpenChallenge", 'More than one row found for challenge $challengeID');

        var row:ResultRow = rows[0];

        var active:Bool = row.getBool("active");
        var resultingGameID:Null<Int> = row.getInt("resulting_game_id");

        if (resultingGameID != null)
        {
            if (active)
                Logging.error("e:Challenge.getOpenChallenge", 'resultingGameID != null for active challenge $challengeID');

            var gameData:Null<GameModelData> = Game.getGame(resultingGameID);

            if (gameData == null)
            {
                Logging.error("e:Challenge.getOpenChallenge", 'resultingGameID = {$resultingGameID} for $challengeID, but a game with such ID was not found');
                return Nonexistent;
            }
            else
                return AlreadyAccepted(gameData);
        }
        else if (active)
            return Active(parseRowAsChallenge(row));
        else
            return Cancelled;
    }

    /* //TODO:

    public static function getAllPendingChallenges():Array<ChallengeData> 
    {
        return Lambda.array(pendingChallengeByID);
    }

    public static function getPublicPendingChallenges():Array<ChallengeData>
    {
        return Lambda.map(pendingPublicChallengeIDs, id -> pendingChallengeByID.get(id));
    }*/

    private function parseRowAsChallenge(row:ResultRow):ChallengeData
    {
        var timeControl:TimeControl = row.getFischerTimeControl("start_secs", "increment_secs");
        var type:ChallengeType = row.getChallengeType("challenge_type", "callee_ref");
        var acceptorColor:Null<PieceColor> = row.getPieceColor("accepting_side_color");
        var customStartingSituation:Null<Situation> = row.getSituation("custom_starting_sip");
        var rated:Bool = row.getBool("rated");

        var data:ChallengeData = new ChallengeData();
        data.id = row.getInt("id");
        data.params = new ChallengeParams(timeControl, type, acceptorColor, customStartingSituation, rated);
        data.ownerRef = row.getPlayerRef("owner_ref");
        data.ownerELO = row.getElo("owner_elo", "owner_relevant_rated_games_cnt");
    }

    private function parseRowsAsChallenges(rows:Array<ResultRow>):Array<ChallengeData>
    {
        var challenges:Array<ChallengeData> = [];

        for (row in rows)
        {
            var data:ChallengeData = parseRowAsChallenge(row);

            challenges.push(data);
        }

        return challenges;
    }

    private function constructAcceptingSide(data:ChallengeData):ChallengeAcceptingSide
    {
        var acceptorColor:Null<PieceColor> = data.params.acceptorColor;
        if (acceptorColor == null)
            return Random;
        else
            return Specified(acceptorColor);
    }
}