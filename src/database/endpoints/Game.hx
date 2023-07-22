package database.endpoints;

import net.shared.dataobj.ChallengeParams;
import net.shared.board.RawPly;
import net.shared.PieceColor;
import net.shared.dataobj.OfferKind;
import net.shared.dataobj.OfferAction;
import net.shared.utils.PlayerRef;
import database.special_values.Timestamp;
import net.shared.Outcome;
import net.shared.dataobj.GameModelData;

class Game 
{
    public static function getGame(database:Database, id:Int):Null<GameModelData>
    {
        return null; //TODO: Implement
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