package;

class Utils 
{
    public static function generateRandomPassword(length:Int) 
    {
        var s:String = "";
        for (i in 0...length)
            s += String.fromCharCode(Math.floor(Math.random() * (127 - 33)) + 33);
        return s;
    }    
}