package com.photodispatcher.event{
	import com.photodispatcher.model.PrintGroup;
	
	import flash.events.Event;
	
	public class PostCompleteEvent extends Event{
		public static const POST_COMPLETE_EVENT:String='postComplete';
		public var printGroup:PrintGroup;
		public var hasErr:Boolean; 
		public var errMsg:String; 
		
		public function PostCompleteEvent(pg:PrintGroup, hasErr:Boolean=false, errMsg:String=''){
			printGroup=pg;
			this.hasErr=hasErr;
			this.errMsg=errMsg;
			super(POST_COMPLETE_EVENT);
		}
	}
}