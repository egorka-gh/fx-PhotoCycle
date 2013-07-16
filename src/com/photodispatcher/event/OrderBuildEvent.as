package com.photodispatcher.event{
	import com.photodispatcher.model.Order;
	
	import flash.events.Event;
	
	public class OrderBuildEvent extends Event{
		public static const BUILDER_ERROR_EVENT:String='builderError';
		public static const ORDER_PREPROCESSED_EVENT:String='orderPreprocessed';

		public var order:Order;
		public var err:int;
		public var err_msg:String;

		
		public function OrderBuildEvent(type:String, order:Order,err:int=0,err_msg:String=''){
			super(type, false, false);
			this.order=order;
			this.err=err;
			this.err_msg=err_msg;
		}
		
		override public function clone():Event{
			var evt:OrderBuildEvent=new OrderBuildEvent(this.type,this.order, this.err,this.err_msg);
			return evt;
		}
		
		
	}
}