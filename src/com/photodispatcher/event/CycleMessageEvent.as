package com.photodispatcher.event{
	import com.photodispatcher.model.mysql.entities.messenger.CycleMessage;
	
	import flash.events.Event;
	
	public class CycleMessageEvent extends Event{
		public static const CYCLE_MESSAGE:String 	= "cyclemessage";

		public var message:CycleMessage;
		
		public function CycleMessageEvent(message:CycleMessage){
			super(CYCLE_MESSAGE, false, false);
			this.message=message;
		}
	}
}