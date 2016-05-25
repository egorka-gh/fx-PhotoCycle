package com.photodispatcher.event{
	import com.photodispatcher.service.glue.GlueMessage;
	
	import flash.events.Event;
	
	public class GlueMessageEvent extends Event	{
		public static const GLUE_MESSAGE:String="gluemessage";
		
		public var message:GlueMessage;

		public function GlueMessageEvent(message:GlueMessage){
			this.message=message;
			super(GLUE_MESSAGE);
		}
	}
}