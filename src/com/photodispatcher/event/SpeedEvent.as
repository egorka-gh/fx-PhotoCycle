package com.photodispatcher.event{
	import flash.events.Event;
	
	public class SpeedEvent extends Event{
		public static const SPEED_EVENT:String="speed";

		public var speed:Number=0;
		
		public function SpeedEvent(speed:Number){
			super(SPEED_EVENT);
			this.speed=speed;
		}
		
		override public function clone():Event{
			return new SpeedEvent(speed);
		}
	}
}