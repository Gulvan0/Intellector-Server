package net.shared.dataobj;

enum Greeting
{
    Simple;
    Login(login:String, password:String);
    Reconnect(token:String, lastProcessedServerEventID:Int, unansweredRequests:Array<Int>);
}