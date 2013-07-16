package com.jxl.chatclient.events
{
	import flash.events.Event;

	public class LoginEvent extends Event
	{
		
		public static const LOGIN:String			= "login";
		
		public var host:String;
		public var port:int;
		public var username:String;
		
		public function LoginEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
	}
}