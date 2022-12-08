package tests;

import entities.util.GameLogEntry;
import net.shared.board.PerformPlyResult;
import entities.util.GameLog;
import net.shared.board.Situation;
import services.GameManager;

using Lambda;
using StringTools;

class SimpleTests 
{
    public static function validateGames() 
    {
        for (i in 0...GameManager.getLastGameID())
        {
            //trace('$i processed');

            //if ([931, 932, 965, 1050, 1209, 1215, 1354, 1435, 1438, 1890, 1947, 2173].has(i + 1))
                //continue;

            var log:GameLog = null;

            try 
            {
                log = GameLog.load(i + 1);
            }
            catch (e)
            {
                trace('Got exception (${i+1})');
                trace(e);
            }

            if (log == null)
                continue;

            var situation:Situation = Situation.defaultStarting();
            var ended:Bool = false;
            var movesPlayed:Int = 0;
            
            var entries:Array<GameLogEntry> = null;

            try 
            {
                entries = log.getEntries();
            }
            catch (e)
            {
                trace('Got exception (${i+1})');
                trace(e);
            }

            for (entry in entries)
            {
                switch entry 
                {
                    case Move(rawPly, _, _):
                        if (!rawPly.from.isValid() || !rawPly.to.isValid())
                        {
                            trace('Invalid from/to: ${i+1}:${movesPlayed+1} $rawPly');
                            break;
                        }

                        if (ended)
                        {
                            trace('Move after ended: ${i+1}:${movesPlayed+1}');
                            break;
                        }

                        var result:PerformPlyResult = null;

                        try 
                        {
                            result = situation.performRawPly(rawPly);
                        }
                        catch (e)
                        {
                            trace('Got exception (${i+1}:${movesPlayed+1})');
                            trace(e);
                            break;
                        }

                        switch result 
                        {
                            case NormalPlyPerformed(_), ProgressivePlyPerformed(_):
                                movesPlayed++;
                            case MateReached, BreakthroughReached:
                                ended = true;
                            case FailedToPerform:
                                trace('Failed to perform rawPly (${i+1}:${movesPlayed+1})');
                                break;
                        }
                    default:
                }
            }
        }
    }    
}