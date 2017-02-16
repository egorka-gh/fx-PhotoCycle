package com.photodispatcher.service.modbus{
	import com.photodispatcher.service.modbus.data.ModbusADU;
	
	import flash.events.Event;
	
	public class ModbusResponseEvent extends Event{
		public static const RESPONSE_EVENT:String = "responseEvent";

		public var adu:ModbusADU;
		public function ModbusResponseEvent(adu:ModbusADU, bubbles:Boolean=false, cancelable:Boolean=false){
			super(RESPONSE_EVENT, bubbles, cancelable);
			this.adu=adu;
		}
		
		override public function clone():Event{
			return new ModbusResponseEvent(adu, bubbles, cancelable);
		}
	}
}