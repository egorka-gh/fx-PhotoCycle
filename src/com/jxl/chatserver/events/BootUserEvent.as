package com.jxl.chatserver.events
{
	import com.jxl.chatserver.vo.ClientVO;
	
	import flash.events.Event;

	public class BootUserEvent extends Event
	{
		public static const BOOT:String					= "boot";
		
		public var user:ClientVO;
		
		public function BootUserEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
		public override function clone():Event
		{
			var evt:BootUserEvent 	= new BootUserEvent(type, bubbles,cancelable);
			evt.user 				= user.clone();
			return evt;
		}
	}
}