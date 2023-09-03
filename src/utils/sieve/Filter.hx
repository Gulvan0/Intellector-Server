package utils.sieve;

enum Filter 
{
    Substring(sub:String, containingRemoved:Bool);
    RegExp(ereg:EReg, rawExpression:String, rawFlags:String, matchingRemoved:Bool);
}