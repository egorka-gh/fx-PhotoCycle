package com.photodispatcher.service.web{
	import com.akmeful.fotokniga.net.AuthService;
	import com.photodispatcher.event.WebEvent;
	import com.photodispatcher.factory.MailPackageBuilder;
	import com.photodispatcher.factory.OrderBuilder;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderExtraInfo;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.provider.fbook.FBookAuthService;
	import com.photodispatcher.util.JsonUtil;
	
	import flash.events.Event;
	
	import mx.rpc.AsyncResponder;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	
	public class FBookCombo extends BaseWeb {
		public static const URL_API:String='api.php';
		public static const API_KEY:String='sp0oULbDnJfk7AjBNtVG';
		
		public static const PARAM_KEY:String='appkey';
		public static const PARAM_COMMAND:String='cmd';
		
		public static const COMMAND_LIST_COMMANDS:String='list';
		
		public static const COMMAND_LIST_ORDERS:String='orders';
		public static const PARAM_STATUS:String='args[status]';
		/*
		30 => 'Принят в работу',
		*/
		public static const PARAM_STATUS_ORDERED_VALUE:int=FotoknigaWeb.ORDER_STATE_PAYMENT_ACCEPTED;
		//public static const PARAM_STATUS_PRELOAD_VALUES:Array=[];
		public static const PARAM_STATUS_PRELOAD_VALUES:Array=[FotoknigaWeb.ORDER_STATE_CHECK,FotoknigaWeb.ORDER_STATE_PAYMENT,FotoknigaWeb.ORDER_STATE_PAYMENT_CHECK];

		
		public static const COMMAND_GET_ORDER_STATE:String='status';
		public static const PARAM_ORDER_ID:String='args[number]';
		
		public static const COMMAND_GET_ORDER_INFO:String='order';
		//public static const PARAM_ORDER_ID:String='args[number]';
		
		public static const COMMAND_GET_PACKAGE_INFO:String='group';
		public static const PARAM_PACKAGE_ID:String='args[number]';

		public static const COMMAND_SET_PACKAGE_STATE:String='group_new_status';
		public static const PARAM_UPDATE_PACKAGE_ID:String='args[id]';
		public static const PARAM_PACKAGE_STATUS:String='args[status]';
		public static const PARAM_PACKAGE_FORCE_STATUS:String='args[ignore_balance]';
		
		public function FBookCombo(source:Source){
			super(source);
		}
		
		private var preloadStates:Array=[];
		private var is_preload:Boolean;
		private var fetchState:int=-1;
		//private var auth:FBookAuthService;
		
		private function login():void{
			//check login
			if(source.fbookSid){
				//login - ok
				login_ResultHandler(null,null);
				return;
			}
			var auth:FBookAuthService= new FBookAuthService();
			auth.method='POST';
			auth.resultFormat='text';
			//attempt to login
			auth.baseUrl=source.fbookService.url;
			var token:AsyncToken;
			token=auth.siteLogin(source.fbookService.user,source.fbookService.pass);
			token.addResponder(new AsyncResponder(login_ResultHandler,login_FaultHandler));
			trace('FBook start login');
		}
		private function login_ResultHandler(event:ResultEvent, token:AsyncToken):void {
			var r:Object;
			if(event) r=JsonUtil.decode(event.result as String);
			if(event==null || r.result){
				trace('FBook login complite sid='+(r!=null?r.sid:source.fbookSid));
				//store sid
				if(r && r.sid) source.fbookSid=r.sid;
				switch (cmd){
					case CMD_SYNC:
						orderes=[];
						is_preload=true;
						preloadStates=PARAM_STATUS_PRELOAD_VALUES.concat();
						startListen();
						getData();
						break;
					case CMD_CHECK_STATE:
						orderes=[];
						startListen();
						//ask order sate
						var post:Object;
						post= new Object();
						post[PARAM_KEY]=API_KEY;
						post[PARAM_COMMAND]=COMMAND_GET_ORDER_INFO;
						post[PARAM_ORDER_ID]=cleanId(_getOrder.src_id);
						if(source.fbookSid) post.sid=source.fbookSid;
						trace('FBook web check project '+_getOrder.src_id+ ' sid:'+source.fbookSid);
						client.getData( new InvokerUrl(baseUrl+URL_API),post);
						break;
					case CMD_GET_PACKAGE:
						startListen();
						//ask mail gruop
						post= new Object();
						post[PARAM_KEY]=API_KEY;
						post[PARAM_COMMAND]=COMMAND_GET_PACKAGE_INFO;
						post[PARAM_PACKAGE_ID]=lastPackageId;
						if(source.fbookSid) post.sid=source.fbookSid;
						trace('FBook web load mail package '+lastPackageId.toString());
						client.getData( new InvokerUrl(baseUrl+URL_API),post);
						break;
					case CMD_SET_PACKAGE_STATE:
						startListen();
						post= new Object();
						post[PARAM_KEY]=API_KEY;
						post[PARAM_COMMAND]=COMMAND_SET_PACKAGE_STATE;
						post[PARAM_UPDATE_PACKAGE_ID]=packageId;
						post[PARAM_PACKAGE_STATUS]=packageState;
						if(forceState) post[PARAM_PACKAGE_FORCE_STATUS]=true;
						if(source.fbookSid) post.sid=source.fbookSid;
						trace('FBook web set package '+packageId.toString()+' state '+packageState.toString()+(forceState?' force':''));
						client.getData( new InvokerUrl(baseUrl+URL_API),post);
						break;

				}
			} else {
				abort('Ошибка подключения к '+source.fbookService.url);
			}
		}
		private function login_FaultHandler(event:FaultEvent, token:AsyncToken):void {
			abort('Ошибка подключения к '+source.fbookService.url+': '+event.fault.faultString);
		}
		
		
		
		override public function sync():void{
			wrongSidCount=0;
			if(!source || source.type!=SourceType.SRC_FBOOK){
				abort('Не верная иннициализация синхронизации');
				return;
			}
			cmd=CMD_SYNC;
			_hasError=false;
			_errMesage='';
			login();
			/*
			orderes=[];
			is_preload=true;
			preloadStates=PARAM_STATUS_PRELOAD_VALUES.concat();
			startListen();
			getData();
			*/
		}
		
		protected function getData():void{
			var post:Object;
			if(!is_preload){
				//complited
				endSync();
				//list ftp
				//listFtp();
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
		
		private var _getOrder:Order;
		override public function get lastOrderId():String{
			return _getOrder?_getOrder.id:'';
		}
		override public function isValidLastOrder(forLoad:Boolean=false):Boolean{
			if(forLoad){
				return (lastOrder && PARAM_STATUS_PRELOAD_VALUES.concat(PARAM_STATUS_ORDERED_VALUE).indexOf(int(lastOrder.src_state))!=-1);
			}else{
				return (lastOrder && int(lastOrder.src_state)==PARAM_STATUS_ORDERED_VALUE);
			}
		}
		override public function getOrder(order:Order):void{
			lastOrder=null;
			wrongSidCount=0;
			//DO NOT KILL used in print check web state 
			if(order && !order.src_id && order.id){
				//create src_id from order.id
				var arr:Array= order.id.split('_');
				if(arr && arr.length>1) order.src_id=arr[1];
			}
			if(!source || source.type!=SourceType.SRC_FBOOK || !order || !order.src_id){
				abort('Не верная иннициализация команды');
				return;
			}
			_getOrder=order;
			cmd=CMD_CHECK_STATE;
			_hasError=false;
			_errMesage='';
			login();
			/*
			orderes=[];
			startListen();
			//ask order sate
			var post:Object;
			post= new Object();
			post[PARAM_KEY]=API_KEY;
			post[PARAM_COMMAND]=COMMAND_GET_ORDER_INFO;
			post[PARAM_ORDER_ID]=cleanId(order.src_id);
			if(source.fbookSid) post.sid=source.fbookSid;
			trace('FBook web check project '+order.src_id+ ' sid:'+source.fbookSid);
			client.getData( new InvokerUrl(baseUrl+URL_API),post);
			*/
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
		
		private var wrongSidCount:int=0;
		override protected function handleData(e:WebEvent):void{
			
			var result:Object=parseRaw(e.data);
			/*
			if(!result){
				abort('Ошибка web: '+e.data);
				source.fbookSid='';
				return;
			}
			*/
			if(!result || !result.hasOwnProperty('result') || !result.result || result.error){
				if(!result){
					abort('Ошибка web: '+e.data);
				}else{
					abort(getErr(result));
				}
				return;
			}

			
			//check sid
			if(result.hasOwnProperty('sid') && result.sid!=source.fbookSid){
				source.fbookSid='';
				if(wrongSidCount<2){
					wrongSidCount++;
					login();
				}else{
					abort('Ошибка web: wrong sid repited');
				}
				return;
			}
			switch (cmd){
				case CMD_SYNC:
					if(!result.hasOwnProperty('result') || !(result.result is Array) || result.error){
						abort(result.error?result.error:'Ошибка структуры данных');
						return;
					}
					//set preload mark
					var a:Array=result.result;
					var it:Object;
					for each(it in a) it.is_preload=is_preload?1:0;
					//add to result
					orderes=orderes.concat(a);
					getData();
					return;
					break;
				case CMD_CHECK_STATE:
					if(!result.hasOwnProperty('result') || !result.result || !result.result.hasOwnProperty('status') || result.error){
						abort(result.error?result.error:'Ошибка структуры данных');
						return;
					}
					_getOrder.src_state=result.result.status;
					//parse extra data
					var arr:Array=OrderBuilder.build(source,[result.result]);
					if(arr && arr.length>0){
						var to:Order=arr[0] as Order;
						if(to){
							/*
							_getOrder.extraInfo.calc_type=to.extraInfo.calc_type;
							_getOrder.extraInfo.endpaper=to.extraInfo.endpaper;
							_getOrder.extraInfo.interlayer=to.extraInfo.interlayer;
							_getOrder.extraInfo.cover=to.extraInfo.cover;
							_getOrder.extraInfo.format=to.extraInfo.format;
							_getOrder.extraInfo.corner_type=to.extraInfo.corner_type;
							_getOrder.extraInfo.kaptal=to.extraInfo.kaptal;
							*/
							_getOrder.extraInfo=to.extraInfo;
							_getOrder.ftp_folder=to.ftp_folder;
							if(to.hasSuborders){
								_getOrder.resetSuborders();
								for each(var so:SubOrder in to.suborders){
									_getOrder.addSuborder(so);
								}
							}
						}
					}
					endGetOrder();
					return;
					break;
				case CMD_GET_PACKAGE:
					//parse package
					lastPackage=MailPackageBuilder.build(source.id, result.result);
					if(!lastPackage || lastPackage.id!=lastPackageId){
						abort('FBook Ошибка загрузки MailPackage id: '+lastPackageId.toString());
						return;
					}
					trace('FBook MailPackage loaded id: '+lastPackageId.toString());
					break;
				case CMD_SET_PACKAGE_STATE:
					if(result.result!='OK'){
						abort('Ошибка сайта при смене статуса группы '+packageId.toString());
						return;
					}
					trace('FBook MailPackage state changed');
					break;

			}
			_hasError=false;
			_errMesage='';
			stopListen();
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		override protected function endGetOrder():void{
			trace('FBook order loaded.');
			_hasError=false;
			_errMesage='';
			stopListen();
			lastOrder=_getOrder;
			trace('FBook loaded order id:'+lastOrder.src_id);
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
			login();
		}
		
		override public function setMailPackageState(id:int, state:int, force:Boolean):void{
			if(!source){
				abort('Не верная иннициализация команды');
				return;
			}
			cmd=CMD_SET_PACKAGE_STATE;
			packageId=id;
			packageState=state;
			forceState=force;
			_hasError=false;
			_errMesage='';
			errCodes=[];
			login();
		}

	}
}