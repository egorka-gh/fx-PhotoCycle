package com.photodispatcher.service.tide{
	import mx.messaging.events.MessageEvent;
	
	import org.granite.tide.data.DataObserver;
	
	public class DataObserver extends org.granite.tide.data.DataObserver{
		
		public function DataObserver(){
			super();
		}
		
		override protected function messageHandler(event:MessageEvent):void{
			trace('DataObserver messageHandler');
			//super.messageHandler(event);
		}
		
		
	}
}