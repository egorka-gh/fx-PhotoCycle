package com.jxl.chatclient.events
{
	import flash.events.Event;

	public class ChatEvent extends Event
	{
		public static const CHAT_MESSAGE:String 					= "chatMessage";
		public static const DISCONNECT:String						= "disconnect";
		
		public var message:String;
		
		public function ChatEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
	}
}