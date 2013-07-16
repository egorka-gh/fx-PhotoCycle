package com.jxl.chat.events
{
	import com.jxl.chat.vo.messages.AbstractMessageVO;
	
	import flash.events.Event;

	public class MessageSocketEvent extends Event
	{
		public static const NEW_MESSAGE:String = "newMessage";
		
		public var message:AbstractMessageVO;
		
		public function MessageSocketEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
	}
}