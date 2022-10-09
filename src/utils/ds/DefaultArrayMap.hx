package utils.ds;

@:forward(set, remove)
abstract DefaultArrayMap<K, V>(Map<K, Array<V>>) from Map<K, Array<V>> to Map<K, Array<V>>
{
    public function get(key:K):Array<V>
    {
        return this.exists(key)? this[key] : [];
    }

    public function push(key:K, value:V)
    {
        if (this.exists(key))
            this[key].push(value);
        else 
            this[key] = [value];
    }

    public function pop(key:K, value:V)
    {
        if (this.exists(key))
        {
            this[key].remove(value);
            if (Lambda.empty(this[key]))
                this.remove(key);
        }
    }

    public function new() 
    {
        this = new Map<K, Array<V>>();    
    }
}