package com.photodispatcher.service.modbus{
	import com.photodispatcher.service.modbus.data.ModbusADU;
	
	import flash.events.Event;
	
	public class ModbusRequestEvent extends Event{
		public static const REQUEST_EVENT:String = "requestEvent";

		public var adu:ModbusADU;
		public var needResponse:Boolean;
		public function ModbusRequestEvent(adu:ModbusADU, needResponse:Boolean, bubbles:Boolean=false, cancelable:Boolean=false){
			super(REQUEST_EVENT, bubbles, cancelable);
			this.adu=adu;
			this.needResponse=needResponse;
		}
		
		override public function clone():Event{
			return new ModbusRequestEvent(adu, needResponse, bubbles, cancelable);
		}
	}
}