package com.photodispatcher.service.web{
	import com.photodispatcher.event.WebEvent;
	import com.photodispatcher.factory.MailPackageBuilder;
	import com.photodispatcher.model.mysql.entities.MailPackageBox;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	
	import flash.events.Event;

	public class PixelParkWeb extends BaseWeb{
		
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
			getInfoSync();
			/*
			if(!source || source.type!=SourceType.SRC_PIXELPARK){
				abort('Не верная иннициализация синхронизации');
				return;
			}
			abort('Неподдерживается сервисом');
			*/
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
				case CMD_GET_INFO_SYNC:
					trace('PixelParkWeb get sync info');
					break;					
				case CMD_SET_PACKAGE_STATE:
					if(result.result!='OK'){
						var msg:String = result.result;
						if (!msg) msg='';
						abort('Ошибка сайта при смене статуса группы '+packageId.toString()+' '+msg);
						return;
					}
					trace('PixelParkWeb MailPackage state changed');
					break;
				//case CMD_GET_INFO_SYNC:
				//case CMD_GET_INFO_LOADER:
					//do nothing just use RawResult
				
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
			url += 'api';
			return url;
		}

		override public function getOrder(order:Order):void{
			lastOrder=order;
			//DO NOT KILL used in print check web state 
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
			var url:String = apiUrl+'/order/' + order.groupId.toString();
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
		
		override public function getMailPackage(packageId:int):void{
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
			var url:String = apiUrl+'/mailpackage/'+packageId.toString();
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
			if(!source){
				abort('Не верная иннициализация команды');
				return;
			}
			var post_state:String;
			switch (state){
				case FotoknigaWeb.ORDER_STATE_MADE:
					post_state = ORDER_STATE_MADE;
					break;
				case FotoknigaWeb.ORDER_STATE_SHIPPED:
					post_state = ORDER_STATE_SHIPPED;
					break;
				//TODO implement other
				default:
					abort('Не верная иннициализация команды (статус)');
					return;
					break;
			}

			cmd=CMD_SET_PACKAGE_STATE;
			packageId=id;
			packageState=state;
			forceState=force;
			_hasError=false;
			_errMesage='';
			errCodes=[];
			//4 Debug
			//errCodes.push(FotoknigaWeb.ERR_CODE_SKIP_NOTIMPLEMENTED);

			var url:String = apiUrl+'/order/'+id.toString()+'/status';
			var post:Object;
			post= new Object();
			post['status']=post_state;

			trace('PixelParkWeb set package state '+id+' ' +post_state);
			startListen();
			client.getData( new InvokerUrl(url),post);

			/*
			errCodes.push(FotoknigaWeb.ERR_CODE_SKIP_NOTIMPLEMENTED);
			abort('Неподдерживается сервисом');
			*/
		}
		
		public function getInfoSync():void{
			if(!source){
				abort('Не верная иннициализация команды');
				return;
			}
			cmd=CMD_GET_INFO_SYNC;
			_hasError=false;
			_errMesage='';
			lastRawResult=null;
			
			startListen();
			//build url
			var url:String = apiUrl + '/info/total';
			trace('PixelParkWeb web get info sync');
			client.getData( new InvokerUrl(url),null);
		}

		public function getInfoLoader():void{
			if(!source){
				abort('Не верная иннициализация команды');
				return;
			}
			cmd=CMD_GET_INFO_LOADER;
			_hasError=false;
			_errMesage='';
			lastRawResult=null;
			
			startListen();
			//build url
			var url:String = apiUrl + '/info/current';
			trace('PixelParkWeb web get info loader');
			client.getData( new InvokerUrl(url),null);
		}

		override public function setBoxState(box:MailPackageBox):void{
			_hasError=false;
			_errMesage='';
			dispatchEvent(new Event(Event.COMPLETE));
		}

	
	}

}