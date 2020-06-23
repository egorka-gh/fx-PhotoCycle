package com.photodispatcher.service.web{
	import com.photodispatcher.event.WebEvent;
	import com.photodispatcher.factory.MailPackageBuilder;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	
	import flash.events.Event;

	public class DummyWeb extends BaseWeb{
		
		public static const ORDER_STATE_READY4PROCESSING:String='ReadyToProcessing';
		//public static const ORDER_STATE_START_LOAD:String='PrepressCoordination';
		//public static const ORDER_STATE_SOFT_ERROR:String='PrepressCoordinationAwaitingReply';
		//public static const ORDER_STATE_SOFT_ERROR_RESUME:String='PrepressCoordinationComplete';
		public static const ORDER_STATE_PROCESSING:String='Printing';
		public static const ORDER_STATE_MADE:String='Printed';
		public static const ORDER_STATE_SHIPPED:String='Shipped';
		public static const ORDER_STATE_CANCELLED:String='Cancelled';
		//public static const ORDER_STATE_CANCELLED_DEFECT:String='CancelledWithDefect';
		//public static const ORDER_STATE_REFUSED:String='Refused';

		public function DummyWeb(source:Source){
			super(source);
		}
		
		override public function syncLoad():void{
			abort('Неподдерживается сервисом');
		}

		override public function syncActiveLoader():void{
			abort('Неподдерживается сервисом');
		}

		override public function sync():void{
			orderes=[];
			endSync();
		}

		override public function getLoaderOrder(order:Order):void{
			abort('Неподдерживается сервисом');
		}

		override public function setLoaderOrderState(order:Order):void{
			abort('Неподдерживается сервисом');
		}
		
		//private var _getOrder:Order;
		override public function get lastOrderId():String{
			//return _getOrder?_getOrder.id:'';
			return lastOrder?lastOrder.id:'';
		}

		override public function isValidLastOrder(forLoad:Boolean=false):Boolean{
			return true;
		}
		
		
/*
		override protected function handleLogin(e:Event):void{
			//do nothing
		}
	*/	
		override protected function handleData(e:WebEvent):void{
			//do nothing
			
			_hasError=false;
			_errMesage='';
			//stopListen();
			dispatchEvent(new Event(Event.COMPLETE));
		}
		

		override public function getOrder(order:Order):void{
			lastOrder=order;
			//DO NOT KILL used in print check web state ??
			if(order && order.groupId == 0){
				//create groupId from order.id
				if (order.id){
					//23_1931615-0
					var idStr:String;
					//remove source
					var arr:Array= order.id.split('_');
					if(arr && arr.length>1){
						idStr=arr[1];
						//remove subnumber
						arr = idStr.split('-');
						if(arr.length>0){
							idStr=arr[0];
							order.groupId =  int(idStr);
						}
					}
				}
			}
			endGetOrder();
		}
		
		//not used
		override protected function endGetOrder():void{
			_hasError=false;
			_errMesage='';
			stopListen();
			trace('PixelParkWeb loaded order id:'+lastOrder.src_id);
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		override public function getMailPackage(packageId:int):void{
			errCodes.push(FotoknigaWeb.ERR_CODE_SKIP_NOTIMPLEMENTED);
			abort('Неподдерживается сервисом');
		}
		
		override public function joinMailPackages(ids:Array):void{
			errCodes.push(FotoknigaWeb.ERR_CODE_SKIP_NOTIMPLEMENTED);
			abort('Неподдерживается сервисом');
		}
		
		override public function setMailPackageState(id:int, state:int, force:Boolean):void{
			errCodes.push(FotoknigaWeb.ERR_CODE_SKIP_NOTIMPLEMENTED);
			abort('Неподдерживается сервисом');
		}
			
	}

}