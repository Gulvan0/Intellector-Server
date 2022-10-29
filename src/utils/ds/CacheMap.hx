package utils.ds;

import haxe.Timer;

class CacheMap<K, V>
{
    private var map:Map<K, V>;
    private var erasureTimers:Map<K, Timer>;

    private var ttl:Int;
    private var loader:Null<K->V>;

    private function onTimeout(k:K)
    {
        erasureTimers.remove(k);
        map.remove(k);
    }

    private function stopTimer(k:K) 
    {
        var timer = erasureTimers.get(k);
        if (timer != null)
        {
            timer.stop();
            erasureTimers.remove(k);
        }
    }

    private function launchTimer(k:K) 
    {
        erasureTimers.set(k, Timer.delay(onTimeout.bind(k), ttl));
    }

    public function set(k:K, v:V) 
    {
        stopTimer(k);
        map.set(k, v);
        launchTimer(k);
    }

    public function remove(k:K)
    {
        stopTimer(k);
        map.remove(k);
    }

    public function get(k:K):V
    {
        if (loader == null || map.exists(k))
            return map.get(k);
        else
        {
            var v:V = loader(k);
            set(k, v);
            return v;
        }
    }

    public function new(map:Map<K, V>, timerMap:Map<K, Timer>, ttlMs:Int, ?loaderFunc:Null<K->V>) 
    {
        this.map = map;
        this.erasureTimers = timerMap;
        this.ttl = ttlMs;
        this.loader = loaderFunc;
    }
}