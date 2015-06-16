package com.photodispatcher.provider.preprocess{
	import com.akmeful.fotokniga.book.data.Book;
	import com.photodispatcher.event.OrderBuildEvent;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.StateLog;
	
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	[Event(name="builderError", type="com.photodispatcher.event.OrderBuildEvent")]
	[Event(name="orderPreprocessed", type="com.photodispatcher.event.OrderBuildEvent")]
	[Event(name="progress", type="com.photodispatcher.event.OrderBuildProgressEvent")]
	public class OrderBuilderBase extends EventDispatcher{
		//public static const TYPE_LOCAL:int=0;
		//public static const TYPE_REMOTE:int=1;
		
		//public var type:int;
		public var lastOrder:Order;
		public var lastError:int=0;
		public var lastErrMsg:String='';
		public var isBusy:Boolean=false;
		public var lastBuildDate:Date= new Date();
		public var skipOnReject:Boolean=false;

		protected var logStates:Boolean=true;
		
		public function OrderBuilderBase(){
			super(null);
		}
		
		public function build(order:Order):void{
			if(isBusy){
				builderError('Internal error. Builder is busy.');
				return;
			}
			lastOrder=order;
			if(!lastOrder){
				builderError('Internal error. Null order.');
				return;
			}
			isBusy=true;
			lastError=0;
			lastErrMsg='';
			startBuild();
		}
		
		public function stop():void{
			//TODO implement
		}

		protected function builderError(msg:String):void{
			isBusy=false;
			lastBuildDate= new Date();
			lastErrMsg=msg;
			dispatchEvent(new OrderBuildEvent(OrderBuildEvent.BUILDER_ERROR_EVENT,lastOrder,-1,msg));
		}

		protected function releaseComplite():void{
			isBusy=false;
			lastBuildDate= new Date();
			lastOrder.state=OrderState.PREPROCESS_COMPLETE;
			if(logStates) StateLog.log(lastOrder.state,lastOrder.id); 
			dispatchEvent(new OrderBuildEvent(OrderBuildEvent.ORDER_PREPROCESSED_EVENT,lastOrder));
		}

		protected function releaseWithError(error:int,msg:String):void{
			isBusy=false;
			lastBuildDate= new Date();
			if(lastOrder.state!=error) lastOrder.state=error;
			lastError=error;
			lastErrMsg=msg;
			if(logStates) StateLog.log(lastOrder.state,lastOrder.id,'',msg); 
			dispatchEvent(new OrderBuildEvent(OrderBuildEvent.ORDER_PREPROCESSED_EVENT,lastOrder,error,msg));
		}

		protected function startBuild():void{
			throw new Error("You need to override startBuild() in your concrete class");
		}
	}
}