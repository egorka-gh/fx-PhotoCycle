package com.photodispatcher.event{
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	
	import flash.events.Event;
	
	public class PostCompleteEventKill extends Event{
		public static const POST_COMPLETE_EVENT:String='postComplete';
		public var printGroup:PrintGroup;
		public var hasErr:Boolean; 
		public var errMsg:String; 
		
		public function PostCompleteEventKill(pg:PrintGroup, hasErr:Boolean=false, errMsg:String=''){
			printGroup=pg;
			this.hasErr=hasErr;
			this.errMsg=errMsg;
			super(POST_COMPLETE_EVENT);
		}
		
		override public function clone():Event{
			var evt:PostCompleteEvent= new PostCompleteEvent(printGroup,hasErr,errMsg);
			return evt;
		}
		
		
	}
}