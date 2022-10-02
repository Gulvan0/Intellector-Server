package net;

import haxe.Exception;
import net.shared.ClientEvent;
import haxe.io.Bytes;

enum NetworkingError //TODO: Add data about user
{
    ConnectionError(error:Dynamic);
    BytesReceived(bytes:Bytes);
    DeserializationError(message:String, exception:Exception);
    ProcessingError(event:ClientEvent, exception:Exception);
}