package com.photodispatcher.event{
	
	import com.photodispatcher.shell.IMCommand;
	import com.photodispatcher.shell.IMRuner;
	
	import flash.events.Event;
	
	public class IMRunerEvent extends Event{
		
		public static const IM_COMPLETED: String = 'imCompleted';
		public static const IM_SEQUENCE_COMPLETED: String = 'imSequenceCompleted';
		
		public var command:IMCommand;
		public var hasError:Boolean;
		public var error:String;
		
		public function IMRunerEvent(type:String, command:IMCommand=null, hasError:Boolean=false, error:String=''){
			super(type, false, false);
			this.command=command;
			this.hasError=hasError;
			this.error=error;
		}
		
		override public function clone():Event{
			return new IMRunerEvent(this.type,this.command,this.hasError,this.error);
		}
		
	}
}