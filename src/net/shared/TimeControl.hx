package net.shared;

enum InternalTimeControl
{
    Correspondence;
    Fischer(startSecs:Int, incrementSecs:Int);
    FixedTimePerMove(secsPerMove:Int);
}

@:forward abstract TimeControl(InternalTimeControl) from InternalTimeControl to InternalTimeControl
{
    public static function construct(firstNumber:Int, secondNumber:Int):TimeControl 
    {
        if (firstNumber > 0)
            return Fischer(firstNumber, secondNumber);
        else if (secondNumber > 0)
            return FixedTimePerMove(secondNumber);
        else
            return Correspondence;
    }

    public function getType():TimeControlType 
    {
        switch this 
        {
            case Correspondence:
                return Correspondence;
            case Fischer(startSecs, incrementSecs):
                return typeByExpectedHalfDuration(startSecs + 40 * incrementSecs);
            case FixedTimePerMove(secsPerMove):
                return typeByExpectedHalfDuration(40 * secsPerMove);
        }
	}

    private function typeByExpectedHalfDuration(expectedHalfDurationSecs:Int):TimeControlType
    {
        if (expectedHalfDurationSecs < 1 * 60)
            return Hyperbullet;
        else if (expectedHalfDurationSecs < 3 * 60)
            return Bullet;
        else if (expectedHalfDurationSecs < 10 * 60)
            return Blitz;
        else if (expectedHalfDurationSecs < 60 * 60)
            return Rapid;
        else 
            return Classic;
    }

    public function toString(ru:Bool):String 
    {
        switch this 
        {
            case Correspondence:
                return ru? 'По переписке' : 'Correspondence';
            case Fischer(startSecs, incrementSecs):
                if (startSecs % 60 == 0)
                    return '${startSecs/60}+$incrementSecs';
                else if (startSecs > 60)
                    return '${Math.floor(startSecs/60)}m${startSecs % 60}s+$incrementSecs';
                else
                    return '${startSecs % 60}s+$incrementSecs';
            case FixedTimePerMove(secsPerMove):
                var postfix:String = ru? ' на ход' : ' per move';
                var timePart:String;
                if (secsPerMove % 60 == 0)
                    timePart = '${secsPerMove/60}';
                else if (secsPerMove > 60)
                    timePart = '${Math.floor(secsPerMove/60)}m${secsPerMove % 60}s';
                else
                    timePart = '${secsPerMove % 60}s';
                return timePart + postfix;
        }
    }
}