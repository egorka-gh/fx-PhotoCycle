package com.photodispatcher.event{
	import flash.events.Event;
	
	public class BusyEvent extends Event{
		public static const BUSY:String='busy';

		public var busyType:int=0;
		public var busyMassage:String;
		
		public function BusyEvent(busyMassage:String,busyType:int=0){
			super(BUSY, false, false);
			this.busyMassage=busyMassage;
			this.busyType=busyType;
		}
	}
}