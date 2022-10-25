package entities.util;

import net.shared.PieceType;
import net.shared.PieceColor;
import struct.Ply;
import struct.HexCoords;
import net.shared.Outcome;
import utils.ds.DefaultCountMap;
import struct.Situation;

enum TryPlyResult
{
    Performed;
    GameEnded(outcome:Outcome);
    Failed;
}

class GameState 
{
    public var moveNum(default, null):Int = 0; //TODO: Use for resign/abandon, offer enabling/disabling
    private var currentSituation:Situation;
    private var plyHistory:Array<Ply> = []; //To simplify rollbacks (caused by takebacks, for example)
    private var situationOccurences:DefaultCountMap<String> = new DefaultCountMap([]); //For threefold repetition check
    private var progressiveMoveNums:Array<Int> = []; //For 60-move rule check

    public function turnColor():PieceColor 
    {
        return currentSituation.turnColor;
    }

    public function tryPly(from:HexCoords, to:HexCoords, morphInto:Null<PieceType>):TryPlyResult
    {
        var turnColor:PieceColor = currentSituation.turnColor;
        var result:PerformPlyResult = currentSituation.performPly(from, to, morphInto);

        switch result 
        {
            case NormalPlyPerformed(ply):
                var situationHash:String = currentSituation.getHash();

                moveNum++;
                plyHistory.push(ply);
                situationOccurences.add(situationHash);

                if (situationOccurences.get(situationHash) >= 3)
                    return GameEnded(Drawish(Repetition));
                else if (moveNum - progressiveMoveNums[progressiveMoveNums.length - 1] >= 60)
                    return GameEnded(Drawish(NoProgress));
                else
                    return Performed;

            case ProgressivePlyPerformed(ply):
                var situationHash:String = currentSituation.getHash();

                moveNum++;
                plyHistory.push(ply);
                situationOccurences.add(situationHash);
                progressiveMoveNums.push(moveNum);

                if (situationOccurences.get(situationHash) >= 3)
                    return GameEnded(Drawish(Repetition));
                else
                    return Performed;

            case MateReached:
                return GameEnded(Decisive(Mate, turnColor));

            case BreakthroughReached:
                return GameEnded(Decisive(Breakthrough, turnColor));

            case FailedToPerform:
                return Failed;
        }
    }

    public function rollback(moveCnt:Int)
    {
        moveNum -= moveCnt;

        for (i in 0...moveCnt)
        {
            var hash:String = currentSituation.getHash();
            situationOccurences.subtract(hash);

            var revertedPly:Ply = plyHistory.pop();
            currentSituation.revertPly(revertedPly);
        }
        
        while (progressiveMoveNums[progressiveMoveNums.length - 1] > moveNum)
            progressiveMoveNums.pop();
    }

    private function initStartingSituation(situation:Situation) 
    {
        currentSituation = situation;
        situationOccurences.add(situation.getHash());
    }

    private function accountFirstPassEntry(entry:GameLogEntry) 
    {
        switch entry 
        {
            case CustomStartingSituation(situation):
                initStartingSituation(situation);
                return;
            default:
        }

        initStartingSituation(Situation.defaultStarting());
    }

    private function accountSecondPassEntry(entry:GameLogEntry) 
    {
        switch entry 
        {
            case Move(from, to, morphInto, _, _):
                tryPly(from, to, morphInto);
            default:
        }
    }

    public static function createFromLog(parsedLog:Array<GameLogEntry>):GameState 
    {
        var state:GameState = new GameState();

        for (entry in parsedLog)
            state.accountFirstPassEntry(entry);
        for (entry in parsedLog)
            state.accountSecondPassEntry(entry);

        return state;
    }

    public static function createNew(?customStartingSituation:Situation):GameState  
    {
        var state:GameState = new GameState();
        
        var startingSituation:Situation = customStartingSituation == null? Situation.defaultStarting() : customStartingSituation;
        state.initStartingSituation(startingSituation);

        return state;
    }

    private function new() 
    {

    }
}