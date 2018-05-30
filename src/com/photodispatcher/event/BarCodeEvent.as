package com.photodispatcher.event{
	import flash.events.Event;
	
	public class BarCodeEvent extends Event{
		public static const BARCODE_DISCONNECTED:String = "barcodeDisConnected";
		public static const BARCODE_CONNECTED:String = "barcodeConnected";
		public static const BARCODE_READED:String = "barcodeReaded";
		public static const BARCODE_ERR:String = "barcodeError";
		public static const BARCODE_DEBUG:String = "barcodeDebug";

		public var barcode:String=''; 
		public var error:String=''; 

		public function BarCodeEvent(type:String, barcode:String, error:String=''){
			super(type, true, false);
			this.barcode = barcode;
			this.error=error;
		}
	}
}