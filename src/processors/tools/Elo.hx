package processors.tools;

import net.shared.utils.MathUtils;
import net.shared.Outcome.PersonalOutcome;
import net.shared.EloValue;
import config.Config;

class Elo 
{
    public static function getNumericalElo(value:EloValue):Int 
    {
        return switch value 
        {
            case None: Config.config.defaultElo;
            case Provisional(elo): elo;
            case Normal(elo): elo;
        }
    }

    public static function recalculateElo(formerElo:EloValue, formerOpponentElo:EloValue, outcome:PersonalOutcome, totalPriorRelevantGames:Int):EloValue
    {
        var score:Float = switch outcome 
        {
            case Win(_): 1;
            case Loss(_): 0;
            case Draw(_): 0.5;
        }

        var calibrationGamesLeft:Int = MathUtils.maxInt(Config.config.calibrationGamesCount - totalPriorRelevantGames, 0); 
        var exp:Float = Config.normalEloLogSlope + (Config.config.maxEloLogSlope - Config.config.normalEloLogSlope) * calibrationGamesLeft / Config.config.calibrationGamesCount;
        var slope:Float = Math.pow(2, exp);

        var playerEloNumber:Int = getNumericalElo(formerElo);
        var opponentEloNumber:Int = getNumericalElo(formerOpponentElo);
        var qPlayer:Float = Math.pow(10, playerEloNumber / 400);
        var qOpponent:Float = Math.pow(10, opponentEloNumber / 400);
        var expectedScore:Float = qPlayer / (qPlayer + qOpponent);

        var newEloNumber:Int = Math.round(playerEloNumber + slope * (score - expectedScore));

        if (calibrationGamesLeft > 0)
            return Provisional(newEloNumber);
        else
            return Normal(newEloNumber);
    }   
}