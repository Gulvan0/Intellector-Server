package database.endpoints;

import net.shared.dataobj.GameEventLogEntry;
import net.shared.dataobj.GameEventLogItem;
import net.shared.dataobj.LegacyFlag;
import net.shared.board.Situation;
import net.shared.utils.UnixTimestamp;
import net.shared.EloValue;
import net.shared.TimeControl;
import sys.db.ResultSet;
import net.shared.dataobj.ChallengeParams;
import net.shared.board.RawPly;
import net.shared.PieceColor;
import net.shared.dataobj.OfferKind;
import net.shared.dataobj.OfferAction;
import net.shared.utils.PlayerRef;
import database.special_values.Timestamp;
import net.shared.Outcome;
import net.shared.dataobj.GameModelData;
import database.QueryShortcut;

class Game 
{
    public static function getGame(database:Database, id:Int, activeSubscribers:Array<PlayerRef>):Null<GameModelData>
    {
        var dataSet:ResultSet = database.simpleSet(GetGameDataByID, ["id" => id]);

        if (!dataSet.hasNext())
            return null;

        var dataRow:ResultRow = dataSet.next();

        var gameID:Int = dataRow.getInt("id");
        var playerRefs:Map<PieceColor, PlayerRef> = [White => dataRow.getPlayerRef("white_player_ref"), Black => dataRow.getPlayerRef("black_player_ref")];
        var startTimestamp:Null<UnixTimestamp> = dataRow.getTimestamp("start_ts");
        var startingSituation:Situation = dataRow.getSituation("custom_starting_sip") ?? Situation.defaultStarting();

        var timeControl:TimeControl = TimeControl.correspondence();

        if (dataRow.getTimeControlType("time_control_type") != Correspondence)
            timeControl = dataRow.getFischerTimeControl("start_secs", "increment_secs");

        var elo:Null<Map<PieceColor, EloValue>> = null;

        if (dataRow.getBool("rated"))
        {
            elo = [];
            elo[White] = dataRow.getElo("white_elo", "white_ranked_games_cnt");
            elo[Black] = dataRow.getElo("black_elo", "black_ranked_games_cnt");
        }
        
        var legacyFlags:Array<LegacyFlag> = [];

        if (id < -1) //TODO: Assign threshold ID
            legacyFlags.push(FakeEventTimestamps);

        var eventRows:Array<ResultRow> = database.simpleRows(GetGameEventsByID, ["id" => id]);

        var eventLog:Array<GameEventLogItem> = [];
        var gameEnded:Bool = false;

        for (row in eventRows)
        {
            var entry:GameEventLogEntry;

            if (row.isNotNull("outcome_type"))
            {
                entry = GameEnded(row.getOutcome("outcome_type", "winner_color"));
                gameEnded = true;
            }
            else if (row.isNotNull("author_ref"))
                entry = Message(row.getPlayerRef("author_ref"), row.getString("msg_text"));
            else if (row.isNotNull("offer_action"))
                entry = OfferActionPerformed(row.getOfferKind("msg_text"), row.getPieceColor("sent_by"), row.getOfferAction("offer_action"));
            else if (row.isNotNull("departure_coord"))
                entry = Ply(row.getPly("departure_coord", "destination_coord", "morph_into"));
            else if (row.isNotNull("cancelled_moves_cnt"))
                entry = Rollback(row.getInt("cancelled_moves_cnt"));
            else
                entry = TimeAdded(row.getPieceColor("receiving_color"));

            eventLog.push({
                ts: row.getTimestamp("event_ts"),
                entry: entry
            });
        }

        var playerOnline:Map<PieceColor, Bool> = [White => false, Black => false];
        var activeSpectators:Array<PlayerRef> = [];

        if (gameEnded)
            activeSpectators = activeSubscribers.copy();
        else
        {
            for (subscriberRef in activeSubscribers)
                if (subscriberRef.equals(playerRefs[White]))
                    playerOnline[White] = true;
                else if (subscriberRef.equals(playerRefs[Black]))
                    playerOnline[Black] = true;
                else
                    activeSpectators.push(subscriberRef);
        }

        return {
            gameID: gameID,
            timeControl: timeControl,
            playerRefs: playerRefs,
            elo: elo,
            startTimestamp: startTimestamp,
            startingSituation: startingSituation,
            legacyFlags: legacyFlags,
            eventLog: eventLog,
            playerOnline: playerOnline,
            activeSpectators: activeSpectators
        }; 
    }

    public static function create(database:Database, playerRefs:Map<PieceColor, PlayerRef>, challengeParams:ChallengeParams):Int
    {
        var gameRow:Array<Dynamic> = [
            null,
            playerRefs[White],
            playerRefs[Black],
            challengeParams.timeControl.getType(),
            challengeParams.rated,
            CurrentTimestamp,
            challengeParams.customStartingSituation
        ];

        var result:QueryExecutionResult = database.insertRow("game.game", gameRow, true);

        var gameID:Int = result.lastID;

        if (!challengeParams.timeControl.isCorrespondence())
            database.insertRow("game.fischer_time_control", [gameID, challengeParams.timeControl.startSecs, challengeParams.timeControl.incrementSecs], false);

        return gameID;
    }

    private static function addEntryToEventLog(database:Database, gameID:Int):Int
    {
        var generalRow:Array<Dynamic> = [
            null,
            gameID,
            CurrentTimestamp
        ];

        var result:QueryExecutionResult = database.insertRow("game.event", generalRow, true);

        return result.lastID;
    }
    
    public static function endGame(database:Database, gameID:Int, outcome:Outcome)
    {
        var eventID:Int = addEntryToEventLog(database, gameID);

        var specificRow:Array<Dynamic> = [
            eventID,
            Utils.extractOutcomeType(outcome),
            Utils.extractWinnerColor(outcome)
        ];

        database.insertRow("game.game_ended_event", specificRow, false);
    }

    public static function appendMessage(database:Database, gameID:Int, authorRef:PlayerRef, messageText:String) 
    {
        var eventID:Int = addEntryToEventLog(database, gameID);

        var specificRow:Array<Dynamic> = [
            eventID,
            authorRef,
            messageText
        ];

        database.insertRow("game.message_event", specificRow, false);
    }

    public static function appendOfferAction(database:Database, gameID:Int, action:OfferAction, kind:OfferKind, sentBy:PieceColor) 
    {
        var eventID:Int = addEntryToEventLog(database, gameID);

        var specificRow:Array<Dynamic> = [
            eventID,
            action,
            kind,
            sentBy
        ];

        database.insertRow("game.offer_event", specificRow, false);
    }

    public static function appendPly(database:Database, gameID:Int, ply:RawPly) 
    {
        var eventID:Int = addEntryToEventLog(database, gameID);

        var specificRow:Array<Dynamic> = [
            eventID,
            ply.from.toScalarCoord(),
            ply.to.toScalarCoord(),
            ply.morphInto
        ];

        database.insertRow("game.ply_event", specificRow, false);
    }

    public static function appendRollback(database:Database, gameID:Int, cancelledMovesCnt:Int) 
    {
        var eventID:Int = addEntryToEventLog(database, gameID);

        var specificRow:Array<Dynamic> = [
            eventID,
            cancelledMovesCnt
        ];

        database.insertRow("game.rollback_event", specificRow, false);
    }

    public static function appendTimeAdded(database:Database, gameID:Int, receivingSide:PieceColor) 
    {
        var eventID:Int = addEntryToEventLog(database, gameID);

        var specificRow:Array<Dynamic> = [
            eventID,
            receivingSide
        ];

        database.insertRow("game.time_added_event", specificRow, false);
    }
}