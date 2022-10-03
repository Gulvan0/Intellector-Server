package net;

import haxe.Exception;
import net.shared.ClientEvent;
import haxe.io.Bytes;

enum NetworkingError
{
    ConnectionError(error:Dynamic);
    BytesReceived(bytes:Bytes);
    DeserializationError(message:String, exception:Exception);
    ProcessingError(event:ClientEvent, exception:Exception);
}