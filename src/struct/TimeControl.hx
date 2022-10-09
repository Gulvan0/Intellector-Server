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
}