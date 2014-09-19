package com.photodispatcher.service.web{
	import com.photodispatcher.event.WebEvent;
	import com.photodispatcher.factory.OrderBuilder;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderExtraInfo;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	
	import pl.maliboo.ftp.FTPFile;

	public class FotoknigaWeb extends BaseWeb{
		public static const URL_API:String='api.php';
		public static const API_KEY:String='sp0oULbDnJfk7AjBNtVG';

		public static const PARAM_KEY:String='appkey';
		public static const PARAM_COMMAND:String='cmd';
		//public static const PARAM_PARAMETRS:String='args';

		public static const COMMAND_LIST_COMMANDS:String='list';

		public static const COMMAND_LIST_ORDERS:String='orders';
		public static const PARAM_STATUS:String='args[status]';
		/*
		20 => 'Ожидает принятия',
		25 => 'Ожидает оплату',
		27 => 'Ожидает проверки оплаты',
		30 => 'Принят в работу'
		*/
		public static const PARAM_STATUS_ORDERED_VALUE:int=30;
		public static const PARAM_STATUS_PRELOAD_VALUES:Array=[20,25,27];

		public static const COMMAND_GET_ORDER_STATE:String='status';
		public static const PARAM_ORDER_ID:String='args[number]';

		public static const COMMAND_GET_ORDER_INFO:String='order';
		//public static const PARAM_ORDER_ID:String='args[number]';

		public function FotoknigaWeb(source:Source){
			super(source);
		}
		
		private var preloadStates:Array=[];
		private var is_preload:Boolean;
		private var fetchState:int=-1;

		override public function sync():void{
			if(!source || source.type!=SourceType.SRC_FOTOKNIGA){
				abort('Не верная иннициализация синхронизации');
				return;
			}
			cmd=CMD_SYNC;
			_hasError=false;
			_errMesage='';
			orderes=[];
			is_preload=true;
			preloadStates=PARAM_STATUS_PRELOAD_VALUES.concat();
			startListen();
			getData();
			/*
			//ask orders
			var post:Object;
			post= new Object();
			post[PARAM_KEY]=API_KEY;
			post[PARAM_COMMAND]=COMMAND_LIST_ORDERS;
			post[PARAM_STATUS]=PARAM_STATUS_ORDERED_VALUE;
			client.getData( new InvokerUrl(baseUrl+URL_API),post);
			*/
		}

		protected function getData():void{
			var post:Object;
			if(!is_preload){
				//complited
				//endSync();
				//list ftp
				listFtp();
				return;
			}
			is_preload=preloadStates.length>0;
			if(is_preload){
				fetchState=preloadStates.pop();
			}else{
				fetchState=PARAM_STATUS_ORDERED_VALUE;
			}
			//ask orders
			post= new Object();
			post[PARAM_KEY]=API_KEY;
			post[PARAM_COMMAND]=COMMAND_LIST_ORDERS;
			post[PARAM_STATUS]=fetchState;
			if(source.fbookSid) post.sid=source.fbookSid;
			client.getData( new InvokerUrl(baseUrl+URL_API),post);
		}

		private function listFtp():void{
			var ftp:FTPList= new FTPList(source);
			ftp.addEventListener(Event.COMPLETE, onFtpList);
			trace('Web sync list ftp: '+ source.ftpService.url)
			ftp.list();
		}
		
		private function onFtpList(evt:Event):void{
			var ftp:FTPList=evt.target as FTPList;
			var listing:Array;
			if(ftp){
				ftp.removeEventListener(Event.COMPLETE, onFtpList);
				if(ftp.hasError){
					abort('Ошибка : '+ftp.errMesage);
					return;
				}
				listing=ftp.listing;
			}
			if(orderes && orderes.length>0 && listing && listing.length>0){
				var obj:Object;
				var ftpfile:FTPFile;
				for each (obj in orderes){
					if(obj && obj.hasOwnProperty('ftp_folder')){
						ftpfile=ArrayUtil.searchItem('name',obj.ftp_folder,listing) as FTPFile;
						if(ftpfile) obj.data_ts=ftpfile.date;
					}
				}
			}
			endSync();
		}
		
		//private var _getOrder:Order;
		override public function get lastOrderId():String{
			//return _getOrder?_getOrder.id:'';
			return lastOrder?lastOrder.id:'';
		}
		override public function isValidLastOrder(forLoad:Boolean=false):Boolean{
			if(forLoad){
				return (lastOrder && PARAM_STATUS_PRELOAD_VALUES.concat(PARAM_STATUS_ORDERED_VALUE).indexOf(int(lastOrder.src_state))!=-1);
			}else{
				return (lastOrder && int(lastOrder.src_state)==PARAM_STATUS_ORDERED_VALUE);
			}
		}
		override public function getOrder(order:Order):void{
			lastOrder=order;
			//DO NOT KILL used in print check web state 
			if(order && !order.src_id && order.id){
				//create src_id from order.id
				var arr:Array= order.id.split('_');
				if(arr && arr.length>1) order.src_id=arr[1];
			}
			if(!source || source.type!=SourceType.SRC_FOTOKNIGA || !order || !order.src_id){
				abort('Не верная иннициализация команды');
				return;
			}
			//_getOrder=order;
			cmd=CMD_CHECK_STATE;
			_hasError=false;
			_errMesage='';
			orderes=[];
			startListen();
			//ask order sate
			var post:Object;
			post= new Object();
			post[PARAM_KEY]=API_KEY;
			//post[PARAM_COMMAND]=COMMAND_GET_ORDER_STATE;
			//TODO use insted COMMAND_GET_ORDER_STATE
			post[PARAM_COMMAND]=COMMAND_GET_ORDER_INFO;
			post[PARAM_ORDER_ID]=cleanId(order.src_id);
			
			if(source.fbookSid) post.sid=source.fbookSid;
			
			client.getData( new InvokerUrl(baseUrl+URL_API),post);
		}
		private function cleanId(src_id:String):int{
			//TODO removes subNumber (-#) for fotokniga
			var a:Array=src_id.split('-');
			var sId:String;
			if(!a || a.length==0){
				sId=src_id;
			}else{
				sId=a[0];
			}
			return int(sId);
		}

		override protected function handleLogin(e:Event):void{
			//do nothing
		}
		
		override protected function handleData(e:WebEvent):void{
			var result:Object;
			switch (cmd){
				case CMD_SYNC:
					result=parseOrders(e.data);
					if(!result || !result.hasOwnProperty('result') || !(result.result is Array) || result.error){
						if(!result){
							abort('Ошибка web: '+e.data);
						}else{
							abort(result.error?result.error:'Ошибка структуры данных');
						}
						return;
					}
					/*
					orderes=result.result;
					endSync();
					*/
					//set preload mark
					var a:Array=result.result;
					var it:Object;
					for each(it in a) it.is_preload=is_preload?1:0;
					//add to result
					orderes=orderes.concat(a);
					getData();
					break;
				case CMD_CHECK_STATE:
					result=parseOrders(e.data);
					if(!result || !result.hasOwnProperty('result') || !result.result || !result.result.hasOwnProperty('status') || result.error){
						abort(result.error?result.error:'Ошибка структуры данных');
						return;
					}
					//_getOrder.src_state=result.result.status;
					lastOrder.src_state=result.result.status;
					//parse extra data
					var arr:Array=OrderBuilder.build(source,[result.result]);
					if(arr && arr.length>0){
						var to:Order=arr[0] as Order;
						if(to && to.extraInfo){
							lastOrder.extraInfo=to.extraInfo;
							/*
							_getOrder.extraInfo= new OrderExtraInfo();
							if(to.extraInfo){
							_getOrder.extraInfo.calc_type=to.extraInfo.calc_type;
							_getOrder.extraInfo.endpaper=to.extraInfo.endpaper;
							_getOrder.extraInfo.interlayer=to.extraInfo.interlayer;
							_getOrder.extraInfo.cover=to.extraInfo.cover;
							_getOrder.extraInfo.format=to.extraInfo.format;
							_getOrder.extraInfo.corner_type=to.extraInfo.corner_type;
							_getOrder.extraInfo.kaptal=to.extraInfo.kaptal;
							}
							*/
						}
					}
					endGetOrder();
					break;
			}
		}
		
		override protected function endGetOrder():void{
			trace('FotoknigaWeb order loaded.');
			_hasError=false;
			_errMesage='';
			stopListen();
			//lastOrder=_getOrder;
			trace('FotoknigaWeb loaded order id:'+lastOrder.src_id);
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
	}
}