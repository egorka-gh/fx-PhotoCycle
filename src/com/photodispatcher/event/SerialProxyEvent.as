package com.photodispatcher.event{
	import flash.events.Event;
	
	public class SerialProxyEvent extends Event{
		public static const SERIAL_PROXY_DATA:String = "serialProxyData";
		public static const SERIAL_PROXY_ERROR:String = "serialProxyError";
		public static const SERIAL_PROXY_START:String = "serialProxyStart";
		public static const SERIAL_PROXY_EXIT:String = "serialProxyExit";
		public static const SERIAL_PROXY_CONNECTED:String = "serialProxyConnected";
		
		public var data:String;
		public var error:String;

		public function SerialProxyEvent(type:String, data:String='', error:String=''){
			super(type, false, false);
			this.data=data;
			this.error=error;
		}
		
		override public function clone():Event{
			return new SerialProxyEvent(type, data, error);
		}
		
		
	}
}