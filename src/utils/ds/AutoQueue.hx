package utils.ds;

import haxe.ds.List;

class AutoQueue<T> 
{
    private var list:List<T> = new List();
    private var length:Int = 0;
    private var maxLength:Int;

    public function push(item:T) 
    {
        if (length == maxLength)
            list.pop();
        list.add(item);
        length++;    
    }

    public function oldest():Null<T>
    {
        return list.first();
    }

    public function new(maxLength:Int) 
    {
        this.maxLength = maxLength;
    }
}