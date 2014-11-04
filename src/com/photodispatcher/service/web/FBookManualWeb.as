package com.photodispatcher.service.web{
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	
	import flash.events.Event;
	
	public class FBookManualWeb extends BaseWeb{
		
		public function FBookManualWeb(source:Source){
			super(source);
		}
		
		override public function getOrder(order:Order):void{
			_hasError=false;
			_errMesage='';
			lastOrder=order;
			dispatchEvent(new Event(Event.COMPLETE));
		}

		override public function get lastOrderId():String{
			return lastOrder?lastOrder.id:'';
		}

		override public function isValidLastOrder(forLoad:Boolean=false):Boolean{
			return true;
		}
		
	}
}