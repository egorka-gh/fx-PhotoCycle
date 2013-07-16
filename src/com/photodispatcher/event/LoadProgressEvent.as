package com.photodispatcher.event{
	import flash.events.Event;
	import flash.events.ProgressEvent;
	
	public class LoadProgressEvent extends ProgressEvent{
		public var caption:String='';
		public var speed:Number=0;

		public function LoadProgressEvent(caption:String='',bytesLoaded:Number=0, bytesTotal:Number=0, speed:Number=0){
			super(ProgressEvent.PROGRESS, false, false, bytesLoaded, bytesTotal);
			this.caption=caption;
			this.speed=speed;
		}

		override public function clone():Event{
			return new LoadProgressEvent(this.caption,this.bytesLoaded, this.bytesTotal,this.speed);
		}

	}
}