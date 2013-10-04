package com.photodispatcher.service.barcode{
	import com.photodispatcher.event.BarCodeEvent;
	
	import flash.events.TimerEvent;

	[Event(name="barcodeReaded", type="com.photodispatcher.event.BarCodeEvent")]
	[Event(name="barcodeError", type="com.photodispatcher.event.BarCodeEvent")]
	public class ComDevice extends ComReader{
		
		public function ComDevice(){
			super(0);
		}
		
		override protected function onTimer(event:TimerEvent):void{
			if (buffer){
				var e:BarCodeEvent=new BarCodeEvent(BarCodeEvent.BARCODE_READED,buffer)
				buffer='';
				dispatchEvent(e);
			}
		}
		
		public function send(msg:String):void{
			_comPort.send(msg);
		}
		
	}
}