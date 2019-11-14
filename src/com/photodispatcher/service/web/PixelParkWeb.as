package com.photodispatcher.service.web{
	import com.photodispatcher.event.WebEvent;
	import com.photodispatcher.factory.MailPackageBuilder;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	
	import flash.events.Event;

	public class PixelParkWeb extends BaseWeb{
		
		public static const URL_API:String='api/';
		public static const URL_STATISTICS:String='statistics/';
		public static const URL_ORDER:String='order/';
		public static const URL_MAILPACKAGE:String='mailpackage/';
		public static const URL_STATUS:String='status/';
		
		
		public static const ORDER_STATE_READY4PROCESSING:String='ReadyToProcessing';
		//public static const ORDER_STATE_START_LOAD:String='PrepressCoordination';
		//public static const ORDER_STATE_SOFT_ERROR:String='PrepressCoordinationAwaitingReply';
		//public static const ORDER_STATE_SOFT_ERROR_RESUME:String='PrepressCoordinationComplete';
		public static const ORDER_STATE_PROCESSING:String='Printing';

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
			return (lastOrder && lastOrder.src_state== ORDER_STATE_PROCESSING);
		}
		
		override public function getOrder(order:Order):void{
			lastOrder=order;
			/* hz
			//DO NOT KILL used in print check web state 
			if(order && !order.src_id && order.id){
				//create src_id from order.id
				var arr:Array= order.id.split('_');
				if(arr && arr.length>1) order.src_id=arr[1];
			}
			*/
			if(!source || source.type!=SourceType.SRC_PIXELPARK || !order || order.groupId==0){
				abort('Не верная иннициализация команды');
				return;
			}
			cmd=CMD_CHECK_STATE;
			_hasError=false;
			_errMesage='';

			orderes=[];
			startListen();
			//ask mail gruop
			//build url
			var url:String = apiUrl;
			url += URL_ORDER;
			url += order.groupId.toString();
			trace('PixelParkWeb web check order '+order.id);
			client.getData( new InvokerUrl(url),null);
		}
		
		//not used
		override protected function endGetOrder():void{
			_hasError=false;
			_errMesage='';
			stopListen();
			trace('PixelParkWeb loaded order id:'+lastOrder.src_id);
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
/*
		override protected function handleLogin(e:Event):void{
			//do nothing
		}
	*/	
		override protected function handleData(e:WebEvent):void{
			var result:Object;
			result=parseRaw(e.data);
			if(!result || result.hasOwnProperty('error') || !result.hasOwnProperty('result') || !result.result){
				if(!result){
					abort('PixelParkWeb Ошибка web: '+e.data+', status:'+client.httpStatus);
				}else{
					abort(getErr(result));
				}
				return;
			}
			
			switch (cmd){
				case CMD_GET_PACKAGE:
					//parse package
					lastPackage=MailPackageBuilder.build(source.id, result.result);
					if(!lastPackage || lastPackage.id!=lastPackageId){
						abort('PixelParkWeb Ошибка загрузки MailPackage id: '+lastPackageId.toString());
						return;
					}
					trace('PixelParkWeb MailPackage loaded; id: '+lastPackageId.toString());
					break;
				case CMD_CHECK_STATE:
					if(!result.result.hasOwnProperty('status')){
						abort('PixelParkWeb Ошибка структуры данных');
						return;
					}
					//_getOrder.src_state=result.result.status;
					lastOrder.src_state=result.result.status;
					trace('PixelParkWeb loaded order id:'+lastOrder.src_id);
					break;
				//TODO implement other
			}
			
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
		
		private function get apiUrl():String {
			var url:String = baseUrl;
			if (url && url.length>0){
				if (url.substr(-1,1) != '/' ){
					url += '/';	
				}
			}
			url += URL_API;
			return url;
		}
		
		override public function getMailPackage(packageId:int):void{
			//TODO implement
			if(!source || !packageId){
				abort('Не верная иннициализация команды');
				return;
			}
			cmd=CMD_GET_PACKAGE;
			lastPackageId=packageId;
			_hasError=false;
			_errMesage='';

			startListen();
			//ask mail gruop
			//build url
			var url:String = apiUrl;
			url += URL_MAILPACKAGE;
			url += packageId.toString();
			trace('PixelParkWeb web load mail package '+lastPackageId.toString());
			client.getData( new InvokerUrl(url),null);
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
			errCodes=[];
			errCodes.push(FotoknigaWeb.ERR_CODE_SKIP_NOTIMPLEMENTED);
			abort('Неподдерживается сервисом');		
		}
	
	}

}