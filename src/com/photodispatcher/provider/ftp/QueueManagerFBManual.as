package com.photodispatcher.provider.ftp{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.entities.SubOrder;
	import com.photodispatcher.provider.fbook.FBookAuthService;
	import com.photodispatcher.provider.fbook.download.FBookDownloadManager;
	import com.photodispatcher.util.JsonUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import mx.rpc.AsyncResponder;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	
	public class QueueManagerFBManual extends QueueManager{
		
		public function QueueManagerFBManual(source:Source=null, remoteMode:Boolean=false){
			super(source, remoteMode);
		}
		
		override public function start(resetErrors:Boolean=false):void{
			lastError='';
			downloadCaption='';
			speed=0;
			
			//check
			if(!source || !source.hasFbookService || source.type!=SourceType.SRC_FBOOK_MANUAL){
				flowError('Ошибка инициализации');
				return;
			}

			connectionsLimit=source.fbookService.connections;

			//detect lockal folder
			var dstFolder:String=Context.getAttribute('workFolder');
			if(!dstFolder){
				flowError('Не задана рабочая папка');
				return;
			}
			var fl:File=new File(dstFolder);
			if(!fl.exists || !fl.isDirectory){
				flowError('Не задана рабочая папка');
				return;
			}
			//check create source folder
			fl=fl.resolvePath(StrUtil.toFileName(source.name));
			try{
				if(!fl.exists) fl.createDirectory();
			}catch(e:Error){
				flowError('Ошибка доступа. Папка: '+fl.nativePath);
				return;
			}
			localFolder=fl.nativePath;
			
			//prt folder
			dstFolder=Context.getAttribute('prtPath');
			if(!dstFolder){
				Context.setAttribute('prtPath',Context.getAttribute('workFolder'));
			}else{
				fl=new File(dstFolder);
				if(!fl.exists || !fl.isDirectory){
					flowError('Не задана папка подготовленных заказов');
					return;
				}
				//check create source folder
				fl=fl.resolvePath(StrUtil.toFileName(source.name));
				try{
					if(!fl.exists) fl.createDirectory();
				}catch(e:Error){
					flowError('Ошибка доступа. Папка: '+fl.nativePath);
					return;
				}
			}
			
			if(resetErrors){
				//reset err limit
				var order:Order;
				for each(order in queue){
					if(order){
						order.resetErrCounter();
						if(order.state<0 && order.state!=OrderState.ERR_WRITE_LOCK){
							resetOrder(order);
							resetOrderState(order);
						}
					}
				}
			}
			trace('QueueManager starting for '+source.fbookService.url);
			//lastError='';
			//startMeter();
			_isStarted=true;
			forceStop=false;
			dispatchEvent(new Event('isStartedChange'));
			
			//start fbook download
			if(!fbDownloadManager){
				fbDownloadManager= new FBookDownloadManager(source,remoteMode);
				//listen
				fbDownloadManager.addEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onFBDownloadManagerLoad);
				fbDownloadManager.addEventListener(ImageProviderEvent.LOAD_FAULT_EVENT,onDownloadFault);
				fbDownloadManager.addEventListener(ProgressEvent.PROGRESS,onFBLoadProgress);
				fbDownloadManager.addEventListener(ImageProviderEvent.FLOW_ERROR_EVENT,onFlowErr);
			}
			fbDownloadManager.start();
			
			startNext();
		}
		
		private function onFBLoadProgress(evt:ProgressEvent):void{
			speed=fbDownloadManager.speed;
		}

		
		override public function reSync(orders:Array):void{
			super.reSync(orders);
			startNext();
		}
		
		private function startNext():void{
			if(!isStarted || forceStop) return;
			login();
			/*
			var newOrder:Order=fetch();
			if(newOrder){
				//create suborder
				var so:SubOrder= new SubOrder();
				so.order_id=newOrder.id;
				so.sub_id=newOrder.src_id;
				so.src_type=SourceType.SRC_FBOOK;
				so.prt_qty=newOrder.fotos_num;
				newOrder.addSuborder(so);
				fbDownloadManager.download(newOrder);
			}
			*/
		}

		private function loadNext():void{
			var newOrder:Order=fetch();
			if(newOrder){
				//create suborder
				var so:SubOrder= new SubOrder();
				so.order_id=newOrder.id;
				so.sub_id=newOrder.src_id;
				so.src_type=SourceType.SRC_FBOOK;
				so.prt_qty=newOrder.fotos_num;
				newOrder.addSuborder(so);
				fbDownloadManager.download(newOrder);
			}
		}
		
		private function login():void{
			if(!source.fbookService || !source.fbookService.url){
				//has no fbook service
				flowError('Не настроен fbook сервис для '+source.name);
				return;
			}
			//attempt to login
			//var auth:AuthService=AuthService.instance;
			var auth:FBookAuthService= new FBookAuthService(); 
			auth.method='POST';
			auth.resultFormat='text';
			auth.baseUrl=source.fbookService.url;
			var token:AsyncToken;
			token=auth.siteLogin(source.fbookService.user,source.fbookService.pass);
			token.addResponder(new AsyncResponder(login_ResultHandler,login_FaultHandler));
			trace('FBook '+source.name+' start login');
		}
		private function login_ResultHandler(event:ResultEvent, token:AsyncToken):void {
			var r:Object;
			if(event) r=JsonUtil.decode(event.result as String);
			if(r.result){
				trace('FBook login complite');
				loadNext();
			} else {
				flowError('Ошибка подключения к '+source.fbookService.url);
			}
		}
		private function login_FaultHandler(event:FaultEvent, token:AsyncToken):void {
			flowError('Ошибка подключения к '+source.fbookService.url+': '+event.fault.faultString);
		}
		
		private function onFBDownloadManagerLoad(event:ImageProviderEvent):void{
			dispatchEvent(event.clone());
			startNext();
		}

		private function onDownloadFault(event:ImageProviderEvent):void{
			//some fatal error
			var order:Order=event.order;
			if(remoteMode){
				if(order){
					if(order.state>=0) order.state=OrderState.ERR_FTP;
					order.setErrLimit();
					resetOrder(order);
				}
				dispatchEvent(event.clone());
				return;
			}
			if(order){
				if(order.state>=0){
					order.state=OrderState.ERR_FTP;
					if(!remoteMode) StateLog.log(OrderState.ERR_FTP,order.id,'',event.error);
				}
				order.setErrLimit();
				resetOrder(order);
				queue.push(order);
				dispatchEvent(new Event('queueLenthChange'));
			}
			
		}
		

	}
}