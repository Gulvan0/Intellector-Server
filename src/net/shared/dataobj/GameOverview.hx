package net.shared.dataobj;

import net.shared.dataobj.GameEventLogItem;
import net.shared.board.Situation;
import net.shared.utils.UnixTimestamp;
import net.shared.EloValue;
import net.shared.utils.PlayerRef;
import net.shared.PieceColor;
import net.shared.TimeControl;

typedef GameOverview =
{
    var gameID:Int;
    var timeControl:TimeControl;
    var playerRefs:Map<PieceColor, PlayerRef>;
    var elo:Null<Map<PieceColor, EloValue>>;
    var startTimestamp:Null<UnixTimestamp>;
    var startingSituation:Situation;

    var partialEventLog:Array<GameEventLogItem>;
}