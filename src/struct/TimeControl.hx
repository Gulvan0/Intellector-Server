package struct;

class TimeControl
{
    public var startSecs:Int;
    public var incrementSecs:Int;

    public function new(startSecs:Int, incrementSecs:Int)
    {
        this.startSecs = startSecs;
        this.incrementSecs = incrementSecs;
    }
}