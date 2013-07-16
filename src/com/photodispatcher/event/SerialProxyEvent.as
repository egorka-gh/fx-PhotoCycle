package com.photodispatcher.event{
	import flash.events.Event;
	
	public class SerialProxyEvent extends Event{
		public static const SERIAL_PROXY_DATA:String = "serialProxyData";
		public static const SERIAL_PROXY_ERROR:String = "serialProxyError";
		
		public var data:String;
		public var error:String;

		public function SerialProxyEvent(type:String, data:String='', error:String=''){
			super(type, false, false);
			this.data=data;
			this.error=error;
		}
	}
}