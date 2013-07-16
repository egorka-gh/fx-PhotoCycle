package com.jxl.chatserver.events
{
	import flash.events.Event;

	public class ChatServerEvent extends Event
	{
		public static const START_SERVER:String 	= "startServer";
		public static const DISCONNECT:String		= "disconnect";
		
		public var host:String;
		public var port:uint;
		
		public function ChatServerEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
	}
}