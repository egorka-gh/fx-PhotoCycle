package com.photodispatcher.event{
	import com.photodispatcher.model.mysql.entities.Order;
	
	import flash.events.Event;
	
	public class OrderPreprocessEvent extends Event{
		//TODO kill 
		public static const ORDER_PREPROCESSED_EVENT:String='orderPreprocessed';
		
		public var order:Order;
		public var err:int;
		public var err_msg:String;

		public function OrderPreprocessEvent(order:Order,err:int=0,err_msg:String=''){
			super(ORDER_PREPROCESSED_EVENT);
			this.order=order;
			this.err=err;
			this.err_msg=err_msg;
		}
	}
}