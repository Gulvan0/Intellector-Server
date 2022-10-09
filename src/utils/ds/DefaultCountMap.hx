package utils.ds;

@:forward(set, remove)
abstract DefaultCountMap<T>(Map<T, Int>) from Map<T, Int> to Map<T, Int>
{
    public function get(key:T):Int
    {
        return this.exists(key)? this[key] : 0;
    }

    public function add(key:T, addend:Int = 1)
    {
        if (this.exists(key))
            this[key] += addend;
        else 
            this[key] = addend;
    }

    public function subtract(key:T, minuend:Int = 1)
    {
        if (this.exists(key) && this[key] > minuend)
            this[key] -= minuend;
        else 
            this.remove(key);
    }

    public function new() 
    {
        this = new Map<T, Int>();    
    }
}