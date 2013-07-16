package com.jxl.chat.events
{
	import flash.events.Event;

	public class PendingMessageEvent extends Event
	{
		public static const SUCCESS:String 		= "success";
		public static const ERROR:String		= "error";
		
		public function PendingMessageEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
	}
}