package com.photodispatcher.event{
	import com.photodispatcher.model.mysql.entities.Order;
	
	import flash.events.Event;
	
	public class OrderLoadedEvent extends Event	{
		public static const ORDER_LOADED_EVENT:String='orderLoaded';
		
		public var order:Order;
		
		public function OrderLoadedEvent(order:Order){
			super(ORDER_LOADED_EVENT);
			this.order=order;
		}
	}
}