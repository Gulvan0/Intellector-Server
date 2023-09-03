package net;

import net.shared.message.ClientMessage;
import haxe.CallStack;
import haxe.Exception;
import haxe.io.Bytes;

enum NetworkingError
{
    ConnectionError(error:Dynamic);
    BytesReceived(bytes:Bytes);
    DeserializationError(message:String, exception:Exception);
    ProcessingError(event:ClientMessage, exception:Exception, stack:CallStack);
}