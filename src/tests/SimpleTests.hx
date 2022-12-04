package tests;

import entities.util.GameLog;
import net.shared.board.Situation;
import services.GameManager;

using Lambda;
using StringTools;

class SimpleTests 
{
    public static function validateGames() 
    {
        for (i in 2173...GameManager.getLastGameID())
        {
            trace('$i processed');

            if ([931, 932, 965, 1050, 1209, 1215, 1354, 1435, 1438, 1890, 1947, 2173].has(i + 1))
                continue;

            var log:GameLog = GameLog.load(i + 1);

            if (log == null || log.get().contains("0000;"))
                continue;

            var situation:Situation = Situation.defaultStarting();
            var ended:Bool = false;
            var movesPlayed:Int = 0;
            for (entry in log.getEntries())
            {
                switch entry 
                {
                    case Move(rawPly, _, _):
                        if (!rawPly.from.isValid() || !rawPly.to.isValid())
                            throw 'Invalid from/to: ${i+1}:${movesPlayed+1} $rawPly';
                        if (ended)
                            throw 'Move after ended: ${i+1}:${movesPlayed+1}';
                        var result = situation.performRawPly(rawPly);
                        switch result 
                        {
                            case NormalPlyPerformed(_), ProgressivePlyPerformed(_):
                                movesPlayed++;
                            case MateReached, BreakthroughReached:
                                ended = true;
                            case FailedToPerform:
                                trace(rawPly);
                                if (!log.playerRefs.has('intellector'))
                                    throw 'Failed to perform: ${i+1}:${movesPlayed+1}';
                        }
                    default:
                }
            }
        }
    }    
}