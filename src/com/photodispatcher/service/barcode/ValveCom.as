package com.photodispatcher.service.barcode{
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	[Event(name="barcodeReaded", type="com.photodispatcher.event.BarCodeEvent")]
	[Event(name="barcodeError", type="com.photodispatcher.event.BarCodeEvent")]
	public class ValveCom extends ComDevice{
		public static const COMMAND_ON:String=' *On';
		public static const COMMAND_OFF:String='*Of';
		
		public function ValveCom(){
			super();
		}
		
		public function setOn():void{
			if(isStarted) send(COMMAND_ON);
		}

		public function setOff():void{
			if(isStarted) send(COMMAND_OFF);
		}

	}
}