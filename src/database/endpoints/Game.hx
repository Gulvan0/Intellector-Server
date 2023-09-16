package database.endpoints;

import processors.nodes.Subscriptions;
import net.shared.dataobj.GameOverview;
import database.special_values.RawInsert;
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

using database.ScalarGetters;

class Game 
{
    //TODO: Rewrite (but first, create filter enum and conversion algorithm)
    /*
    private typedef GetGamesOutput = {dataRows:Array<ResultRow>, eventRows:Array<ResultRow>};
    
    private static function getGamesByCondition(condition:String, full:Bool):Null<GetGamesOutput>
    {
        var dataRows:Array<ResultRow> = Database.instance.simpleRows(GetGameData, ["condition" => Raw(condition)]);
        var eventRows:Array<ResultRow> = Database.instance.simpleRows(full? GetGameEvents : GetOverviewGameEvents, ["condition" => Raw(condition)]);

        return {
            dataRows: dataRows, 
            eventRows: eventRows
        };
    }

    public static function getGames(condition:String):Array<GameOverview>
    {
        
    }*/

    public static function getGame(id:Int):Null<GameModelData>
    {
        var dataSet:ResultSet = Database.instance.simpleSet(GetGameData, null, {concreteGameID: id});

        if (!dataSet.hasNext())
            return null;

        var dataRow:ResultRow = dataSet.next();

        var gameID:Int = dataRow.getInt("id");
        var playerRefs:Map<PieceColor, PlayerRef> = [White => dataRow.getPlayerRef("white_player_ref"), Black => dataRow.getPlayerRef("black_player_ref")];
        var startTimestamp:Null<UnixTimestamp> = dataRow.getTimestamp("start_ts");
        var startingSituation:Situation = dataRow.getSituation("starting_sip");

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

        if (id < -1) //TODO: Rewrite
            legacyFlags.push(FakeEventTimestamps);

        var eventRows:Array<ResultRow> = Database.instance.simpleRows(GetGameEvents, null, {concreteGameID: id});

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

        var activeSubscribers:Array<PlayerRef> = Subscriptions.getObservers(Game(id, null)).map(x -> x.getReference());

        var playerOnline:Map<PieceColor, Bool> = [White => false, Black => false];
        var activeSpectators:Array<PlayerRef> = [];

        if (gameEnded)
            activeSpectators = activeSubscribers;
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

    public static function create(playerRefs:Map<PieceColor, PlayerRef>, challengeParams:ChallengeParams):Int
    {
        var gameRow:Array<Dynamic> = [
            null,
            playerRefs[White],
            playerRefs[Black],
            challengeParams.timeControl.getType(),
            challengeParams.rated,
            CurrentTimestamp,
            null,
            null
        ];

        var result:QueryExecutionResult = Database.instance.insertRow("game.game", gameRow, true);

        var gameID:Int = result.lastID;

        if (!challengeParams.timeControl.isCorrespondence())
            Database.instance.insertRow("game.fischer_time_control", [gameID, challengeParams.timeControl.startSecs, challengeParams.timeControl.incrementSecs], false);

        var startingSituation:Situation = challengeParams.customStartingSituation ?? Situation.defaultStarting();
        Database.instance.insertRow("game.encountered_situation", [gameID, 0, startingSituation], true);

        return gameID;
    }

    private static function addEntryToEventLog(gameID:Int):Int
    {
        var generalRow:Array<Dynamic> = [
            null,
            gameID,
            CurrentTimestamp
        ];

        var result:QueryExecutionResult = Database.instance.insertRow("game.event", generalRow, true);

        return result.lastID;
    }
    
    public static function endGame(gameID:Int, outcome:Outcome)
    {
        var eventID:Int = addEntryToEventLog(gameID);

        var specificRow:Array<Dynamic> = [
            eventID,
            Utils.extractOutcomeType(outcome),
            Utils.extractWinnerColor(outcome)
        ];

        Database.instance.insertRow("game.game_ended_event", specificRow, false);
    }

    public static function appendMessage(gameID:Int, authorRef:PlayerRef, messageText:String) 
    {
        var eventID:Int = addEntryToEventLog(gameID);

        var specificRow:Array<Dynamic> = [
            eventID,
            authorRef,
            messageText
        ];

        Database.instance.insertRow("game.message_event", specificRow, false);
    }

    public static function appendOfferAction(gameID:Int, action:OfferAction, kind:OfferKind, sentBy:PieceColor) 
    {
        var eventID:Int = addEntryToEventLog(gameID);

        var specificRow:Array<Dynamic> = [
            eventID,
            action,
            kind,
            sentBy
        ];

        Database.instance.insertRow("game.offer_event", specificRow, false);
    }

    public static function appendPly(gameID:Int, ply:RawPly) 
    {
        var eventID:Int = addEntryToEventLog(gameID);

        var specificRow:Array<Dynamic> = [
            eventID,
            ply.from.toScalarCoord(),
            ply.to.toScalarCoord(),
            ply.morphInto
        ];

        Database.instance.insertRow("game.ply_event", specificRow, false);

        var resultRow:ResultRow = Database.instance.simpleRows(GetMostRecentSituation, null, {concreteGameID: gameID})[0];

        var currentSituation:Situation = resultRow.getSituation("most_recent_sip");
        var lastPlyNum:Int = resultRow.getInt("max_ply_num");
        
        var nextSituation:Situation = currentSituation.situationAfterRawPly(ply);
        var nextPlyNum:Int = lastPlyNum + 1;
        
        Database.instance.insertRow("game.encountered_situation", [gameID, nextPlyNum, nextSituation], true);
    }

    public static function appendRollback(gameID:Int, cancelledMovesCnt:Int) 
    {
        var eventID:Int = addEntryToEventLog(gameID);

        var specificRow:Array<Dynamic> = [
            eventID,
            cancelledMovesCnt
        ];

        Database.instance.insertRow("game.rollback_event", specificRow, false);
    }

    public static function appendTimeAdded(gameID:Int, receivingSide:PieceColor) 
    {
        var eventID:Int = addEntryToEventLog(gameID);

        var specificRow:Array<Dynamic> = [
            eventID,
            receivingSide
        ];

        Database.instance.insertRow("game.time_added_event", specificRow, false);
    }
}