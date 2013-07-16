package com.photodispatcher.event{
	import flash.events.Event;
	import flash.events.ProgressEvent;
	
	public class OrderBuildProgressEvent extends ProgressEvent{
		public var caption:String='';
		
		public function OrderBuildProgressEvent(caption:String='',bytesLoaded:Number=0, bytesTotal:Number=0){
			super(ProgressEvent.PROGRESS, false, false, bytesLoaded, bytesTotal);
			this.caption=caption;
		}
		
		override public function clone():Event{
			return new OrderBuildProgressEvent(this.caption,this.bytesLoaded, this.bytesTotal);
		}
		
	}
}