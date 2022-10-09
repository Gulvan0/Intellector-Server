package services;

import utils.MathUtils;
import net.shared.EloValue;

class EloManager 
{
    public static function getNumericalElo(value:EloValue):Int 
    {
        return switch value 
        {
            case None: Config.defaultElo;
            case Provisional(elo): elo;
            case Normal(elo): elo;
        }
    }

    public static function recalculateElo(formerElo:EloValue, formerOpponentElo:EloValue, score:Int, totalPriorGames:Int):EloValue
    {
        var calibrationGamesLeft:Int = MathUtils.maxInt(Config.calibrationGamesCount - totalPriorGames, 0); 
        var exp:Float = Config.normalEloLogSlope + (Config.maxEloLogSlope - Config.normalEloLogSlope) * calibrationGamesLeft / Config.calibrationGamesCount;
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