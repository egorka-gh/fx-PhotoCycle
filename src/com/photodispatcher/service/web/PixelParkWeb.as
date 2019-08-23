package com.photodispatcher.service.web{
	import com.photodispatcher.event.WebEvent;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	
	import flash.events.Event;

	public class PixelParkWeb extends BaseWeb{
		
		public function PixelParkWeb(source:Source){
			super(source);
		}
		
		override public function syncLoad():void{
			if(!source || source.type!=SourceType.SRC_PIXELPARK){
				abort('Не верная иннициализация синхронизации');
				return;
			}
			abort('Неподдерживается сервисом');
		}

		override public function syncActiveLoader():void{
			if(!source || source.type!=SourceType.SRC_PIXELPARK){
				abort('Не верная иннициализация синхронизации');
				return;
			}
			abort('Неподдерживается сервисом');
		}

		override public function sync():void{
			if(!source || source.type!=SourceType.SRC_PIXELPARK){
				abort('Не верная иннициализация синхронизации');
				return;
			}
			abort('Неподдерживается сервисом');
		}

		override public function getLoaderOrder(order:Order):void{
			if(!source || source.type!=SourceType.SRC_PIXELPARK){
				abort('Не верная иннициализация синхронизации');
				return;
			}
			abort('Неподдерживается сервисом');
		}

		override public function setLoaderOrderState(order:Order):void{
			if(!source || source.type!=SourceType.SRC_PIXELPARK){
				abort('Не верная иннициализация синхронизации');
				return;
			}
			abort('Неподдерживается сервисом');
		}
		
		//private var _getOrder:Order;
		override public function get lastOrderId():String{
			//return _getOrder?_getOrder.id:'';
			return lastOrder?lastOrder.id:'';
		}

		override public function isValidLastOrder(forLoad:Boolean=false):Boolean{
			//TODO implement
			return true;
		}
		
		override public function getOrder(order:Order):void{
			//TODO implement
			lastOrder=order;
			//DO NOT KILL used in print check web state 
			if(order && !order.src_id && order.id){
				//create src_id from order.id
				var arr:Array= order.id.split('_');
				if(arr && arr.length>1) order.src_id=arr[1];
			}
			if(!source || source.type!=SourceType.SRC_PIXELPARK || !order || !order.src_id){
				abort('Не верная иннициализация команды');
				return;
			}
			endGetOrder();
		}
		
		override protected function endGetOrder():void{
			_hasError=false;
			_errMesage='';

			stopListen();
			//lastOrder=_getOrder;
			trace('FotoknigaWeb loaded order id:'+lastOrder.src_id);
			dispatchEvent(new Event(Event.COMPLETE));
		}
		

		override protected function handleLogin(e:Event):void{
			//do nothing
		}
		
		override protected function handleData(e:WebEvent):void{
			//do nothing
			//TODO implement

			_hasError=false;
			_errMesage='';
			stopListen();
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		/* TODO implement ??
		override protected function endGetOrder():void{
			is_newAPI=false;
			trace('FotoknigaWeb order loaded.');
			_hasError=false;
			_errMesage='';
			stopListen();
			//lastOrder=_getOrder;
			trace('FotoknigaWeb loaded order id:'+lastOrder.src_id);
			dispatchEvent(new Event(Event.COMPLETE));
		}
		*/
		
		override public function getMailPackage(packageId:int):void{
			//TODO implement
			if(!source || !packageId){
				abort('Не верная иннициализация команды');
				return;
			}
			abort('Неподдерживается сервисом');		
		}
		
		override public function joinMailPackages(ids:Array):void{
			//TODO implement
			if(!source || !ids || ids.length==0){
				abort('Не верная иннициализация команды');
				return;
			}
			abort('Неподдерживается сервисом');		
		}
		
		override public function setMailPackageState(id:int, state:int, force:Boolean):void{
			//TODO implement
			if(!source){
				abort('Не верная иннициализация команды');
				return;
			}
			abort('Неподдерживается сервисом');		
		}
	
	}

}