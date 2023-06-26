package database;

import net.shared.board.Situation;
import net.shared.PieceColor;
import net.shared.dataobj.ChallengeType;
import net.shared.TimeControl;
import net.shared.dataobj.ChallengeParams;
import sys.db.ResultSet;
import net.shared.dataobj.ChallengeData;
import net.shared.utils.PlayerRef;

class TypedQueries 
{
    public static function simpleRows(database:Database, query:QueryShortcut, substitutions:Map<String, Dynamic>):Array<ResultRow>
    {
        var a:Array<ResultRow> = [];

        for (row in database.executeQuery(query, substitutions)[0].set)
            a.push(row);

        return a;
    }

    public static function getIncomingChallenges(database:Database, calleeRef:PlayerRef):Array<ChallengeData>
    {
        for (row in simpleRows(database, GetActiveIncomingChallenges, ["callee_ref" => calleeRef]))
        {
            var timeControl:TimeControl = row.getFischerTimeControl("start_secs", "increment_secs");
            var type:ChallengeType = Direct(calleeRef);
            var acceptorColor:Null<PieceColor> = row.getPieceColor("accepting_side_color");
            var customStartingSituation:Null<Situation> = row.getSituation("custom_starting_sip");
            var rated:Bool = row.getBool("rated");

            var data:ChallengeData = new ChallengeData();
            data.id = row.getInt("id");
            data.params = new ChallengeParams(timeControl, type, acceptorColor, customStartingSituation, rated);
            data.ownerRef = row.getPlayerRef("owner_ref");
            data.ownerELO = row.getElo("owner_elo", "owner_relevant_rated_games_cnt");

            incomingChallenges.push(data);
        }
    }    
}