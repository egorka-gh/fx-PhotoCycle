package com.photodispatcher.event{
	import com.photodispatcher.model.PrintGroup;
	
	import flash.events.Event;
	
	public class PrintEvent extends Event{
		public static const MANAGER_ERROR_EVENT:String='managerError';
		public static const POST_COMPLETE_EVENT:String='postComplete';
		
		public var printGroup:PrintGroup;
		public var hasErr:Boolean; 
		public var errMsg:String; 

		public function PrintEvent(type:String, pg:PrintGroup=null, errMsg:String=''){
			super(type);
			printGroup=pg;
			this.errMsg=errMsg;
			if(errMsg) this.hasErr=true;
		}
		
		override public function clone():Event{
			return new PrintEvent(type, printGroup, errMsg);
		}
		
	}
}