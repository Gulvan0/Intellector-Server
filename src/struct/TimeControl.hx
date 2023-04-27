package struct;

import net.shared.TimeControlType;

class TimeControl
{
    public var startSecs:Int;
    public var incrementSecs:Int;

    public function new(startSecs:Int, incrementSecs:Int)
    {
        this.startSecs = startSecs;
        this.incrementSecs = incrementSecs;
    }

    public function toString(ru:Bool):String 
    {
        if (isCorrespondence())
            return ru? 'По переписке' : 'Correspondence';
        else if (startSecs % 60 == 0)
            return '${startSecs/60}+$incrementSecs';
        else if (startSecs > 60)
            return '${Math.floor(startSecs/60)}m${startSecs % 60}s+$incrementSecs';
        else
            return '${startSecs % 60}s+$incrementSecs';
    }

    public function getType():TimeControlType 
    {
		var determinant:Int = startSecs + 40 * incrementSecs;
        if (determinant == 0)
            return Correspondence;
        else if (determinant < 1 * 60)
            return Hyperbullet;
        else if (determinant < 3 * 60)
            return Bullet;
        else if (determinant < 10 * 60)
            return Blitz;
        else if (determinant < 60 * 60)
            return Rapid;
        else 
            return Classic;
	}

    public function isCorrespondence():Bool
    {
		return getType() == Correspondence;
    }
    
    public static function correspondence() 
    {
        return new TimeControl(0, 0);
    }
}