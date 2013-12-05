package com.photodispatcher.event{
	import flash.events.Event;
	
	public class ControllerMesageEvent extends Event{
		public static const CONTROLLER_MESAGE_EVENT:String='controllerMesage';

		public var chanel:int;
		public var state:int;
		
		public function ControllerMesageEvent(chanel:int, state:int){
			super(CONTROLLER_MESAGE_EVENT, false, false);
			this.chanel=chanel;
			this.state=state;
		}
	}
}