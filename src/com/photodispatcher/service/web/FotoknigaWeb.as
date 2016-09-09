package com.photodispatcher.service.web{
	import com.photodispatcher.event.WebEvent;
	import com.photodispatcher.factory.MailPackageBuilder;
	import com.photodispatcher.factory.OrderBuilder;
	import com.photodispatcher.factory.OrderLoadBuilder;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderExtraInfo;
	import com.photodispatcher.model.mysql.entities.OrderLoad;
	import com.photodispatcher.model.mysql.entities.OrderTemp;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.provider.fbook.FBookAuthService;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.util.JsonUtil;
	
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayCollection;
	import mx.rpc.AsyncResponder;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	
	import pl.maliboo.ftp.FTPFile;
	
	import spark.formatters.DateTimeFormatter;

	public class FotoknigaWeb extends BaseWeb{
		public static const ERR_CODE_BALANCE:int=24;

		public static const ORDER_STATE_NONE:int=0;
		public static const ORDER_STATE_CREATED:int=10;
		public static const ORDER_STATE_READY:int=15;
		public static const ORDER_STATE_CHECKOUT:int=17;
		public static const ORDER_STATE_CHECK:int=20;
		public static const ORDER_STATE_PAYMENT:int=25;
		public static const ORDER_STATE_PAYMENT_CHECK:int=27;
		public static const ORDER_STATE_PAYMENT_ACCEPTED:int=30;
		public static const ORDER_STATE_MADE:int=40;
		public static const ORDER_STATE_DELIVERY:int=42;
		public static const ORDER_STATE_RECEIVING:int=45;
		public static const ORDER_STATE_SHIPPED:int=50;
		public static const ORDER_STATE_RECEIVED:int=60;
		public static const ORDER_STATE_ARCHIVED:int=100;

		public static const URL_API:String='api.php';
		public static const API_KEY:String='sp0oULbDnJfk7AjBNtVG';

		public static const URL_API_NEW:String='api/';
		
		public static const PARAM_KEY:String='appkey';
		public static const PARAM_ACTION:String='action';
		
		public static const PARAM_COMMAND:String='cmd';
		//public static const PARAM_PARAMETRS:String='args';

		public static const COMMAND_LIST_COMMANDS:String='list';

		public static const COMMAND_LIST_ORDERS:String='orders';
		public static const PARAM_STATUS:String='args[status]';
		//cmd=orders&args[statuses][]=20&args[statuses][]=25&args[statuses][]=30
		public static const PARAM_STATUSES:String='args[statuses][]';
		/*
		20 => 'Ожидает принятия',
		25 => 'Ожидает оплату',
		27 => 'Ожидает проверки оплаты',
		30 => 'Принят в работу'
		*/
		public static const PARAM_STATUS_ORDERED_VALUE:int=ORDER_STATE_PAYMENT_ACCEPTED;
		public static const PARAM_STATUS_PRELOAD_VALUES:Array=[ORDER_STATE_CHECK,ORDER_STATE_PAYMENT,ORDER_STATE_PAYMENT_CHECK];

		public static const COMMAND_GET_ORDER_STATE:String='status';
		public static const PARAM_ORDER_ID:String='args[number]';

		public static const COMMAND_GET_ORDER_INFO:String='order';
		//public static const PARAM_ORDER_ID:String='args[number]';

		public static const COMMAND_GET_PACKAGE_INFO:String='group';
		public static const PARAM_PACKAGE_ID:String='args[number]';
		
		//cmd=union_groups&args[ids][]=12&args[ids][]=13
		public static const COMMAND_JOIN_PACKAGES:String='union_groups';
		public static const PARAM_PACKAGE_IDS:String='args[ids][]';
		
		//cmd=group_new_status&args[id]=1111&args[status]=30
		//cmd=group_new_status&args[id]=1111&args[status]=30&args[ignore_balance]=true
		public static const COMMAND_SET_PACKAGE_STATE:String='group_new_status';
		public static const PARAM_UPDATE_PACKAGE_ID:String='args[id]';
		public static const PARAM_PACKAGE_STATUS:String='args[status]';
		public static const PARAM_PACKAGE_FORCE_STATUS:String='args[ignore_balance]';
		
		public static const ACTION_GET_LOADER_ORDERS:String='fk:get_ready_orders';
		public static const ACTION_GET_LOADER_ORDER:String='fk:get_order_files';
		public static const ACTION_SET_LOADER_ORDER_STATE:String='fk:set_order_folder_status';
		
		public function FotoknigaWeb(source:Source){
			super(source);
		}
		
		private var preloadStates:Array=[];
		private var is_preload:Boolean;
		private var nextState:int=-1;
		private var auth:FBookAuthService;
		private var is_newAPI:Boolean=false;
		
		private function login():void{
			if(!source.fbookService || !source.fbookService.url){
				//has no fbook service
				login_ResultHandler(null,null);
				return;
			}
			//check login
			//var auth:AuthService=AuthService.instance;
			if(!auth){ 
				auth= new FBookAuthService(); //AuthService();
				auth.method='POST';
				auth.resultFormat='text';
			}
			if(!auth.authorized){ // || !source.fbookSid){
				//attempt to login
				auth.baseUrl=source.fbookService.url;
				var token:AsyncToken;
				token=auth.siteLogin(source.fbookService.user,source.fbookService.pass);
				token.addResponder(new AsyncResponder(login_ResultHandler,login_FaultHandler));
				trace('FotoknigaWeb start login');
			}else{
				login_ResultHandler(null,null);
			}
		}
		private function login_ResultHandler(event:ResultEvent, token:AsyncToken):void {
			var r:Object;
			if(event) r=JsonUtil.decode(event.result as String);
			if(event==null || r.result){
				trace('FotoknigaWeb login complite or not configured');
				var post:Object;
				switch (cmd){
					case CMD_SYNC:
						orderes=[];
						is_preload=true;
						nextState=-1;
						preloadStates=PARAM_STATUS_PRELOAD_VALUES.concat();
						startListen();
						//getData();
						startSync();
						break;
					case CMD_SYNC_LDR:
						orderes=[];
						startListen();
						//ask loader orders 4 sync
						post= new Object();
						post[PARAM_KEY]=appKey;
						post[PARAM_ACTION]=ACTION_GET_LOADER_ORDERS;
						trace('FotoknigaWeb web sync orders 4 load; action:'+ACTION_GET_LOADER_ORDERS);
						client.getData( new InvokerUrl(baseUrl+URL_API_NEW),post);
						break;
					case CMD_GET_ORDER_LDR:
						orderes=[];
						startListen();
						//ask loader order by id
						post= new Object();
						post[PARAM_KEY]=appKey;
						post[PARAM_ACTION]=ACTION_GET_LOADER_ORDER;
						post['id']=int(lastOrder.src_id);
						trace('FotoknigaWeb web get order 4 load; action:'+ACTION_GET_LOADER_ORDER+'; id:'+lastOrder.src_id);
						client.getData( new InvokerUrl(baseUrl+URL_API_NEW),post);
						break;
					case CMD_SET_ORDER_LDR_STATE:
						//4debug
						/* 4 debug
						_hasError=false;
						_errMesage='';
						dispatchEvent(new Event(Event.COMPLETE));
						break;
						*/
						
						startListen();
						//set loader order state
						post= new Object();
						post[PARAM_KEY]=appKey;
						post[PARAM_ACTION]=ACTION_SET_LOADER_ORDER_STATE;
						post['id']=int(lastOrder.src_id);
						post['status']=int(lastOrder.src_state);
						if(lastOrder.errStateComment){
							post['info']=lastOrder.errStateComment;
						}
						trace('FotoknigaWeb set state order 4 load; action:'+ACTION_SET_LOADER_ORDER_STATE+', '+lastOrder.src_id+', '+lastOrder.src_state);
						client.getData( new InvokerUrl(baseUrl+URL_API_NEW),post);
						break;
					
					case CMD_CHECK_STATE:
						orderes=[];
						startListen();
						//ask order sate
						post= new Object();
						post[PARAM_KEY]=API_KEY;
						post[PARAM_COMMAND]=COMMAND_GET_ORDER_INFO;
						post[PARAM_ORDER_ID]=cleanId(lastOrder.src_id);
						if(source.fbookSid) post.sid=source.fbookSid;
						trace('FotoknigaWeb web check project '+lastOrder.src_id);
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
						trace('FotoknigaWeb web load mail package '+lastPackageId.toString());
						client.getData( new InvokerUrl(baseUrl+URL_API),post);
						break;
					case CMD_JOIN_PACKAGE:
						startListen();
						post= new Object();
						post[PARAM_KEY]=API_KEY;
						post[PARAM_COMMAND]=COMMAND_JOIN_PACKAGES;
						post[PARAM_PACKAGE_IDS]=joinIds;
						if(source.fbookSid) post.sid=source.fbookSid;
						trace('FotoknigaWeb web join packages ' + joinIds.join(', '));
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
						trace('FotoknigaWeb web set package '+packageId.toString()+' state '+packageState.toString()+(forceState?' force':''));
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
		
		override public function syncLoad():void{
			if(!source || source.type!=SourceType.SRC_FOTOKNIGA){
				abort('Не верная иннициализация синхронизации');
				return;
			}
			if(!appKey){
				abort('Не назначен appKey для web сервиса');
				return;
			}
			cmd=CMD_SYNC_LDR;
			_hasError=false;
			_errMesage='';
			is_newAPI=true;
			login();
		}
		
		

		override public function sync():void{
			is_newAPI=false;
			if(!source || source.type!=SourceType.SRC_FOTOKNIGA){
				abort('Не верная иннициализация синхронизации');
				return;
			}
			cmd=CMD_SYNC;
			_hasError=false;
			_errMesage='';
			login();
		}
		
		private function startSync():void{
			is_newAPI=false;
			var post:Object;
			post= new Object();
			post[PARAM_KEY]=API_KEY;
			post[PARAM_COMMAND]=COMMAND_LIST_ORDERS;
			var states:Array=PARAM_STATUS_PRELOAD_VALUES.concat();
			states.push(PARAM_STATUS_ORDERED_VALUE);
			post[PARAM_STATUSES]=states;
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

		override public function getLoaderOrder(order:Order):void{
			if(!source || source.type!=SourceType.SRC_FOTOKNIGA || !order || !int(order.src_id)){
				abort('Не верная иннициализация команды');
				return;
			}
			is_newAPI=true;
			lastOrder=order;
			cmd=CMD_GET_ORDER_LDR;
			_hasError=false;
			_errMesage='';
			login();
		}

		override public function setLoaderOrderState(order:Order):void{
			if(!source || source.type!=SourceType.SRC_FOTOKNIGA || !order || !int(order.src_id) || !int(order.src_state)){
				abort('Не верная иннициализация команды');
				return;
			}
			is_newAPI=true;
			lastOrder=order;
			cmd=CMD_SET_ORDER_LDR_STATE;
			_hasError=false;
			_errMesage='';
			login();
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
			is_newAPI=false;
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
			cmd=CMD_CHECK_STATE;
			_hasError=false;
			_errMesage='';
			login();
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
		
		private function logSyncData(raw:Object):void{
			if(!raw) return;
			var syncData:String=raw as String;
			if(!syncData) return;

			var fmt:DateTimeFormatter=new DateTimeFormatter(); 
			fmt.dateTimePattern='yy-MM-dd HH:mm:ss'; 
			syncData='--------------------------------------------------------------'+'\n'
					+fmt.format(new Date())+' sync:'+source.sync.toString()+'\n'
					+syncData+'\n';
			var folderName:String=source.getWrkFolder();
			var file:File=new File(folderName);
			if(!file.exists || !file.isDirectory) return;
			file=file.resolvePath('syncLog.txt');
			try{
				var fs:FileStream = new FileStream();
				fs.open(file, FileMode.APPEND);
				fs.writeUTFBytes(syncData);
				fs.close();
			} catch(err:Error){
			}
		}
		
		override protected function handleData(e:WebEvent):void{
			var result:Object;
			result=parseRaw(e.data);
			//check 4 err
			if(is_newAPI){
				//if(result!='OK'){
					if(!result || result.hasOwnProperty('error')){
						if(!result){
							abort('FotoknigaWeb Ошибка web: '+e.data);
						}else{
							abort(result.error);
						}
						return;
					}
				//}
			}else{
				if(!result || !result.hasOwnProperty('result') || !result.result || result.error){
					if(!result){
						abort('FotoknigaWeb Ошибка web: '+e.data);
					}else{
						abort(getErr(result));
					}
					return;
				}
			}
			
			var a:Array;
			switch (cmd){
				case CMD_SYNC:
					if(!(result.result is Array)){
						abort('FotoknigaWeb Ошибка структуры данных');
						return;
					}
					//set preload mark
					a=result.result;
					var it:Object;
					//for each(it in a) it.is_preload=is_preload?1:0;
					for each(it in a){
						it.is_preload=1;
						if(it.status==PARAM_STATUS_ORDERED_VALUE) it.is_preload=0;
					}
					//add to result
					orderes=orderes.concat(a);
					listFtp();
					return;
					break;
				case CMD_SYNC_LDR:
					//parse ids
					var key:String;
					var ot:OrderTemp;
					var src_id:int;
					for(key in result){
						src_id=int(result[key]);
						if(src_id){
							ot=new OrderTemp();
							ot.source=source.id;
							ot.src_id=src_id.toString();
							ot.id=source.id.toString()+'_'+src_id.toString();
							orderes.push(ot);
						}
					}
					//complited
					break;
				case CMD_GET_ORDER_LDR:
					//parse order
					var ol:OrderLoad=OrderLoadBuilder.build(source,result);
					if(ol){
						//set result
						var str:String=ol.ftp_folder;
						if(str && str.substr(0,7)=='orders/') str=str.substr(7);
						lastOrder.ftp_folder=str;//ol.ftp_folder;
						lastOrder.fotos_num=ol.fotos_num;
						lastOrder.files=ol.files as ArrayCollection;
					}else{
						abort('FotoknigaWeb Ошибка структуры данных');
						return;
					}
					endGetOrder();
					return;
					break;
				case CMD_SET_ORDER_LDR_STATE:
					//complited
					break;

				case CMD_CHECK_STATE:
					if(!result.result.hasOwnProperty('status')){
						abort('FotoknigaWeb Ошибка структуры данных');
						return;
					}
					//_getOrder.src_state=result.result.status;
					lastOrder.src_state=result.result.status;
					//parse extra data
					var arr:Array=OrderBuilder.build(source,[result.result],false,lastOrder.src_id);
					if(arr && arr.length>0){
						var to:Order=arr[0] as Order;
						if(to){
							if(to.extraInfo){
								to.extraInfo.id=lastOrder.id;
								to.extraInfo.sub_id='';
								to.extraInfo.parseMessages();
								lastOrder.extraInfo=to.extraInfo;
							}
							lastOrder.production=to.production;
							if(to.fotos_num>0) lastOrder.fotos_num=to.fotos_num;
							if(to.hasSuborders){
								lastOrder.resetSuborders();
								//can be just 1 so
								var so:SubOrder=to.suborders.getItemAt(0) as SubOrder;
								if(so) lastOrder.addSuborder(so);
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
						abort('FotoknigaWeb Ошибка загрузки MailPackage id: '+lastPackageId.toString());
						return;
					}
					trace('FotoknigaWeb MailPackage loaded id: '+lastPackageId.toString());
					break;
				case CMD_JOIN_PACKAGE:
					//if(result.hasOwnProperty('return') && result['return'].hasOwnProperty('id')) joinResultId=result['return']['id'];
					if(result.result && result.result.hasOwnProperty('id')) joinResultId=result.result.id;
					if(joinResultId==0){
						abort('Ошибка сайта при обединении групп, не определенн id группы результата');
						return;
					}
					trace('FotoknigaWeb MailPackages join complited');
					break;
				case CMD_SET_PACKAGE_STATE:
					if(result.result!='OK'){
						abort('Ошибка сайта при смене статуса группы '+packageId.toString());
						return;
					}
					trace('FotoknigaWeb MailPackage state changed');
					break;
			}
			_hasError=false;
			_errMesage='';
			stopListen();
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
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
		
		override public function getMailPackage(packageId:int):void{
			is_newAPI=false;
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
		
		override public function joinMailPackages(ids:Array):void{
			is_newAPI=false;
			if(!source || !ids || ids.length==0){
				abort('Не верная иннициализация команды');
				return;
			}
			cmd=CMD_JOIN_PACKAGE;
			joinIds=ids;
			joinResultId=0;
			_hasError=false;
			_errMesage='';
			login();
		}
		
		override public function setMailPackageState(id:int, state:int, force:Boolean):void{
			is_newAPI=false;
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