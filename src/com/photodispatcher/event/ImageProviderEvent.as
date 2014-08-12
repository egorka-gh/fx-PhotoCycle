package com.photodispatcher.event{
	import com.photodispatcher.model.mysql.entities.Order;
	
	import flash.events.Event;
	
	public class ImageProviderEvent extends Event{
		public static const FLOW_ERROR_EVENT:String 	='flowError';
		public static const FETCH_NEXT_EVENT:String 	='fetchNext';
		public static const ORDER_LOADED_EVENT:String	='orderLoaded';
		public static const LOAD_FAULT_EVENT:String		='loadFault';
		
		public var order:Order;
		public var error:String;

		public function ImageProviderEvent(type:String,order:Order=null,error:String=''){
			super(type, false, false);
			this.error=error;
			this.order=order;
		}
		
		override public function clone():Event{
			return new ImageProviderEvent(type,order,error);
		}
	}
}