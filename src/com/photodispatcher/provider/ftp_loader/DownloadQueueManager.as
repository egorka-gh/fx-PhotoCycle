package com.photodispatcher.provider.ftp_loader{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.ConnectionsProgressEvent;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.event.LoadProgressEvent;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.mysql.AsyncLatch;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.AliasForward;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderFile;
	import com.photodispatcher.model.mysql.entities.OrderLoad;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.OrderLoadService;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.service.web.FTPList;
	import com.photodispatcher.service.web.FotoknigaWeb;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	
	import org.granite.tide.Tide;
	
	import pl.maliboo.ftp.FTPFile;
	
	[Event(name="progress", type="flash.events.ProgressEvent")]
	[Event(name="orderLoaded", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="flowError", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="loadFault", type="com.photodispatcher.event.ImageProviderEvent")]
	public class DownloadQueueManager extends EventDispatcher{
		public static const RESTART_TIMEOUT:int=10000;
		public static const PRODUCTION_ERR_RESET_DELAY:int=1000*60*3;
		public static const WEB_ERRORS_LIMIT:int=3;
		public static const ORDERS_INPROCESS_LIMIT:int=5;
		
		protected var forceStop:Boolean;
		
		protected var _source:Source;
		public function get source():Source{
			return _source;
		}

		/*
		*orders Queue
		*/
		//protected var queue:Array=[];
		public var queue:ArrayCollection;
		
		protected var localFolder:String;
		
		private var downloadManager:FTPDownloadManager;
		[Bindable]
		private var webTimer:Timer;
		private var webErrCounter:int=0;
		private var webApplicant:Order;
		
		public function DownloadQueueManager(source:Source=null){
			super(null);
			queue=new ArrayCollection();
			_source=source;
			if(this.source) sourceCaption=this.source.name;
			if(source && source.ftpService) connectionsLimit=source.ftpService.connections;
		}
		
		protected var _isStarted:Boolean=false;
		[Bindable(event="isStartedChange")]
		public function get isStarted():Boolean{
			return _isStarted;
		}

		[Bindable(event="queueLenthChange")]
		public function get queueLenth():int{
			return queue.length;
		}

		[Bindable]
		public var sourceCaption:String='';
		[Bindable]
		public var downloadCaption:String='';
		[Bindable]
		public var speed:Number=0;
		[Bindable]
		public var connectionsLimit:int=0;
		[Bindable]
		public var connectionsActive:int=0;
		[Bindable]
		public var connectionsFree:int=0;
		[Bindable]
		public var connectionsPending:int=0;
		[Bindable]
		public var lastError:String='';
		
		private function get bdService():OrderLoadService{
			return Tide.getInstance().getContext().byType(OrderLoadService,true) as OrderLoadService;
		}

		public function start():void{
			//reset
			webErrCounter=0;
			if(webTimer) webTimer.stop(); 
			resetOrderState(webApplicant);
			webApplicant=null;

			lastError='';
			downloadCaption='';
			if(source && source.ftpService) connectionsLimit=source.ftpService.connections;
			
			//check
			if(!source){
				flowError('Ошибка инициализации');
				return;
			}
			/*
			//check config production
			if(source.type==SourceType.SRC_FOTOKNIGA && Context.getProduction()==0){
				flowError('Не назначено производство');
				return;
			}
			*/
			//detect lockal folder
			var dstFolder:String=Context.getAttribute('workFolder');
			if(!dstFolder){
				flowError('Не задана рабочая папка');
				return;
			}
			var file:File=new File(dstFolder);
			if(!file.exists || !file.isDirectory){
				flowError('Не задана рабочая папка');
				return;
			}
			//check create source folder
			file=file.resolvePath(StrUtil.toFileName(source.name));
			try{
				if(!file.exists) file.createDirectory();
			}catch(e:Error){
				flowError('Ошибка доступа. Папка: '+file.nativePath);
				return;
			}
			localFolder=file.nativePath;
			
			//reset runtime states
			for each(var order:Order in queue.source){
				//TODO check refactor
				if(order){
					//reset 
					if(order.state<OrderState.FTP_INCOMPLITE){
						resetOrder(order);
						resetOrderState(order);
					}
				}
			}

			trace('QueueManager starting for '+source.ftpService.url);
			_isStarted=true;
			forceStop=false;
			dispatchEvent(new Event('isStartedChange'));
			
			//start ftp download
			if(!downloadManager){
				downloadManager= new FTPDownloadManager(source);
				//listen
				downloadManager.addEventListener(ImageProviderEvent.FETCH_NEXT_EVENT,onDownloadManagerNeedOrder);
				//downloadManager.addEventListener(ImageProviderEvent.FLOW_ERROR_EVENT,onDownloadManagerFlowError);
				downloadManager.addEventListener(ImageProviderEvent.FILE_LOADED_EVENT,onDownloadManagerLoadFile);
				downloadManager.addEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onDownloadManagerLoad);
				downloadManager.addEventListener(ImageProviderEvent.LOAD_FAULT_EVENT,onDownloadFault);
				downloadManager.addEventListener(ProgressEvent.PROGRESS,onLoadProgress);
				downloadManager.addEventListener(ConnectionsProgressEvent.CONNECTIONS_PROGRESS_EVENT, onConnProgress);
				//downloadManager.addEventListener(SpeedEvent.SPEED_EVENT, onSpeed);
				downloadManager.addEventListener(ImageProviderEvent.FLOW_ERROR_EVENT,onFlowErr);
			}
			downloadManager.start();
			//checkQueue();
		}

		public function destroy():void{
			if(isStarted) stop();
			if(downloadManager){
				downloadManager.removeEventListener(ImageProviderEvent.FETCH_NEXT_EVENT,onDownloadManagerNeedOrder);
				//downloadManager.removeEventListener(ImageProviderEvent.FLOW_ERROR_EVENT,onDownloadManagerFlowError);
				downloadManager.removeEventListener(ImageProviderEvent.FILE_LOADED_EVENT,onDownloadManagerLoadFile);
				downloadManager.removeEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onDownloadManagerLoad);
				downloadManager.removeEventListener(ImageProviderEvent.LOAD_FAULT_EVENT,onDownloadFault);
				downloadManager.removeEventListener(ProgressEvent.PROGRESS,onLoadProgress);
				downloadManager.removeEventListener(ConnectionsProgressEvent.CONNECTIONS_PROGRESS_EVENT, onConnProgress);
				//downloadManager.removeEventListener(SpeedEvent.SPEED_EVENT, onSpeed);
				downloadManager.removeEventListener(ImageProviderEvent.FLOW_ERROR_EVENT,onFlowErr);
				downloadManager.destroy();
				downloadManager=null;
			}
		}
		
		public function stop():void{
			_isStarted=false;
			forceStop=true;
			speed=0;
			resetOrderState(webApplicant);
			webApplicant=null;
			if(webTimer) webTimer.stop();
			var order:Order;
			
			//stop download
			var stopedOrders:Array=[];
			if(downloadManager) stopedOrders=downloadManager.stop();
			
			//reset stoped
			for each(order in stopedOrders){
				if(order){
					resetOrder(order);
					resetOrderState(order);	
					//queue.unshift(order);
					queue.addItem(order);
				}
			}
			
			//reset runtime states
			for each(order in queue.source){
				if(order){
					if(order.state<OrderState.FTP_INCOMPLITE){
						resetOrder(order);
						resetOrderState(order);
					}
				}
			}
			
			dispatchEvent(new Event('queueLenthChange'));
			dispatchEvent(new Event('isStartedChange'));
			trace('QueueManager stop '+(source.ftpService?source.ftpService.url:source.name));
		}

		public function reSync(orders:Array):void{
			trace('QueueManager reSync '+(source.ftpService?source.ftpService.url:source.name));
			if(!orders) return;
			
			if(webTimer) webTimer.stop();
			webErrCounter=0;
			
			//reSync in download first
			if(downloadManager) downloadManager.reSync(orders);
			//apply resync filter
			var syncOrders:Array=orders.filter(reSyncFilter);
			if(syncOrders.length==0){
				//nothig to process
				//clear queue
				queue=new ArrayCollection();
				dispatchEvent(new Event('queueLenthChange'));
				return;
			}
			
			//keep current, remove if not in sync, add new
			var syncMap:Object= arrayToMap(syncOrders);
			var toKill:Array=[];
			var toReplace:Array=[];
			var idx:int;
			var order:Order;
			//check queue
			for each (order in queue.source){
				if(order){
					if (syncMap[order.id]){
						//some bug vs ftp list, may be wrong order data
						var o:Order;
						if(order.state<0 && order.exceedErrLimit) o=syncMap[order.id] as Order;
						if(o){
							//new wlbe added from syncMap vs err limt
							o.state=order.state;
							o.state_date=order.state_date;
							o.setErrLimit();
							o.resume_load=false;
							//del old from queue
							toKill.push(order);
						}else{
							//replace
							toReplace.push(order);
							//remove from map
							delete syncMap[order.id];
						}
					}else{
						toKill.push(order);
					}
				}
			}
			//remove
			for each (order in toKill){
				var arr:Array=queue.source;
				if(order){
					if(webApplicant && webApplicant.id==order.id) webApplicant=null;
					idx=ArrayUtil.searchItemIdx('id', order.id, arr);
					if(idx!=-1) arr.splice(idx,1);
					//removeOrder(order);
				}
				queue= new ArrayCollection(arr);
			}
			//replace
			for each (order in toReplace){
				if(order){
					idx=ArrayUtil.searchItemIdx('id',order.id,orders);
					if(idx!=-1){
						orders[idx]=order;
					}
				}
			}
			//add new to queue
			for each (order in syncMap){
				if(order){
					order.ftpForwarded=order.state==OrderState.FTP_FORWARD;
					//queue.push(order);
					queue.addItem(order);
				}
			}
			
			/*wrong sort on date
			//sort queue
			queue.sortOn(['state_date'],[Array.NUMERIC]);
			*/
			
			dispatchEvent(new Event('queueLenthChange'));
			//if(isStarted) checkQueue();
			if(isStarted && downloadManager) downloadManager.start(); //???
		}
		private function reSyncFilter(element:*, index:int, arr:Array):Boolean {
			var o:Order=element as Order;
			//return o!=null && o.state==syncState;
			//return o!=null && source && o.source==source.id && (o.state==OrderState.WAITE_FTP || o.state<0);
			return o!=null && source && o.source==source.id && o.state>=OrderState.FTP_WAITE && o.state<=OrderState.FTP_CAPTURED;
			//return o!=null && source && o.source==source.id && (o.state==OrderState.WAITE_FTP || o.state==OrderState.FTP_CAPTURED);
		}
		private function arrayToMap(arr:Array):Object{
			var map:Object=new Object();
			if(!arr || arr.length==0) return map;
			var id:String;
			for each(var o:Object in arr){
				id=o.id;
				if(id){
					map[id]=o;
				}
			}
			return map;
		}

		protected function fetch():Order{
			var newOrder:Order;
			var ord:Order;
			//chek queue
			for each (ord in queue.source){
				if(ord && !ord.exceedErrLimit){
					if(ord.state>0){
						//fetch
						if(ord.state>=OrderState.FTP_WAITE && ord.state<=OrderState.FTP_CAPTURED){
							//resetOrderState(newOrder) if not FTP_WAITE or FTP_CAPTURED
							if(ord && ord.state!=OrderState.FTP_WAITE && ord.state!=OrderState.FTP_WAITE_AFTER_ERROR && ord.state!=OrderState.FTP_CAPTURED) resetOrderState(ord);
							if(ord.state==OrderState.FTP_CAPTURED && (!ord.files || ord.files.length==0)){
								//fill vs files
								loadFromBD(ord);
							}else{
								if(!newOrder) newOrder=ord;
							}
						}
					}else if(ord.state!=OrderState.ERR_CHECK_MD5){
						//reset error
						resetOrderState(ord);
					}
				}
			}
			return newOrder;
		}
		
		private function checkQueue():void{
			if(webApplicant || !isStarted || forceStop) return;
			var newOrder:Order=fetch();
			if(newOrder){
				if(newOrder.state==OrderState.FTP_WAITE || newOrder.state==OrderState.FTP_WAITE_AFTER_ERROR || newOrder.state==OrderState.FTP_CAPTURED){
					webApplicant=newOrder;
					webApplicant.saveState();
					if(webApplicant.state==OrderState.FTP_WAITE || newOrder.state==OrderState.FTP_WAITE_AFTER_ERROR){
						//load from site
						trace('QueueManager web getOrder '+webApplicant.id);
						downloadCaption='Загрузка с сайта ' +webApplicant.id;
						webApplicant.state=OrderState.FTP_WEB_CHECK;
						StateLog.log(OrderState.FTP_WEB_CHECK,webApplicant.id);
						var webService:BaseWeb=WebServiceBuilder.build(source);
						webService.addEventListener(Event.COMPLETE,onGetOrderWeb);
						webService.getLoaderOrder(webApplicant);
					}else if(webApplicant.state==OrderState.FTP_CAPTURED){
						//already locked 4 load push to loader
						startList();
					}
				}else{
					//her poime
					//wrong state remove, must never happend
					StateLog.log(OrderState.ERR_WRONG_STATE,newOrder.id,'','DownloadQueueManager.checkQueue state='+newOrder.state.toString());
					removeOrder(newOrder);
				}
			}
		}
		
		private function loadFromBD(order:Order):void{
			if(!order) return;
			order.saveState();
			order.state=OrderState.FTP_GET_PROJECT;
			var latch:DbLatch= new DbLatch(true);
			latch.addEventListener(Event.COMPLETE, onloadFromBD);
			latch.addLatch(bdService.loadById(order.id),order.id);
			latch.start();
		}
		private function onloadFromBD(evt:Event):void{
			var latch:DbLatch=evt.target as DbLatch;
			var result:OrderLoad;
			if(latch){
				latch.removeEventListener(Event.COMPLETE, onloadFromBD);
				var order:Order=ArrayUtil.searchItem('id',latch.lastTag,queue.source) as Order;
				if(latch.complite) result=latch.lastDataItem as OrderLoad;
				if(!result || result.state!=OrderState.FTP_CAPTURED){
					removeOrder(order);
					return;
				}
				if(!order) return;
				order.files=result.files as ArrayCollection;
				if(!order.files || order.files.length==0){
					order.state=OrderState.ERR_GET_PROJECT;
					removeOrder(order);
					return;
				}
				order.restoreState();
				if(downloadManager.queueLenth==0) checkQueue();
			}
		}

		//private var webStatelatch:AsyncLatch;
		
		private function onGetOrderWeb(e:Event):void{
			var pw:BaseWeb=e.target as BaseWeb;
			pw.removeEventListener(Event.COMPLETE,onGetOrderWeb);
			if(!webApplicant || webApplicant.state!=OrderState.FTP_WEB_CHECK){
				//removed from queue or some else
				//check next or stop
				checkQueue();
				return;
			}

			trace('getOrder complited: '+webApplicant.id);
			
			if(pw.hasError){
				trace('getOrder web order err: '+pw.errMesage);
				webErrCounter++;
				webApplicant.state=OrderState.ERR_WEB;
				lastError='Ошибка сайта '+webApplicant.id+' :'+pw.errMesage;
				StateLog.log(OrderState.ERR_WEB,webApplicant.id,'','Ошибка на сайте: '+pw.errMesage);
				removeOrder(webApplicant);
				webApplicant=null;
				//to prevent cycle web check when network error or offline
				if(webErrCounter>WEB_ERRORS_LIMIT){
					flowError('Ошибка web: '+pw.errMesage);
				}else{
					checkQueueLate();
				}
				return;
			}
			
			webErrCounter=0;
			var ord:Order;
			var latch:DbLatch;
			
			//check if not locked
			if(!webApplicant.canChangeRemoteState){
				//can't change site state
				webApplicant.state=OrderState.ERR_WEB;
				lastError='Запрет смены статуса на сайте '+webApplicant.id;
				StateLog.log(OrderState.ERR_WEB,webApplicant.id,'','Запрет смены статуса на сайте '+webApplicant.id);
				removeOrder(webApplicant);
				webApplicant=null;
				checkQueue();
				return;
			}
			
			if(!webApplicant.files || webApplicant.files.length==0){
				// 'Пустой список файлов'
				//check if order forwarded
				//get order info
				pw.addEventListener(Event.COMPLETE,onGetOrderInfo);
				pw.getOrder(webApplicant);
				return;
			}
			
			var err:String=chekSiteFiles(webApplicant.files);
			if(err){
				trace('getOrder web order err: '+err);
				StateLog.log(OrderState.ERR_GET_PROJECT,webApplicant.id,'',err);
				webApplicant.state=OrderState.FTP_INCOMPLITE;
				webApplicant.saveState();
				webApplicant.src_state=OrderLoad.REMOTE_STATE_ERROR.toString();
				webApplicant.files=null;
				setOrderStateWeb(webApplicant,OrderLoad.REMOTE_STATE_ERROR,err,pw);
				//save in bd
				latch= new DbLatch(true);
				latch.addLatch(bdService.save(OrderLoad.fromOrder(webApplicant),0));
				latch.start();
				removeOrder(webApplicant);
				webApplicant=null;
				checkQueueLate();
				return;
			}
			
			//set site copy state, set bd state FTP_CAPTURED  
			setOrderStateWeb(webApplicant,OrderLoad.REMOTE_STATE_COPY,'',pw);
			
		}
		private function chekSiteFiles(files:ArrayCollection):String{
			var err:String='';
			if(!files || files.length==0){
				return 'Пустой список файлов (косяк)';
			}else{
				var map:Object=new Object;
				var of:OrderFile;
				for each(of in files){
					if(!of || !of.file_name) return 'Не определено имя файла';
					if(map.hasOwnProperty(of.file_name)){
						map[of.file_name]++;
					}else{
						map[of.file_name]=1;
					}
				}
				//check unique
				var key:String;
				for(key in map){
					if(map[key]>1) err=err+key+' ';
				}
				if(err) err='Не уникальное имя файла: '+err;
			}
			return err;
		}
		
		private function onGetOrderInfo(e:Event):void{
			var pw:BaseWeb=e.target as BaseWeb;
			pw.removeEventListener(Event.COMPLETE,onGetOrderInfo);
			if(!webApplicant || webApplicant.state!=OrderState.FTP_WEB_CHECK) return;
			if(pw.hasError){
				trace('onGetOrderInfo web order err: '+pw.errMesage);
				webErrCounter++;
				webApplicant.state=OrderState.ERR_WEB;
				lastError='Ошибка сайта '+webApplicant.id+' :'+pw.errMesage;
				StateLog.log(OrderState.ERR_WEB,webApplicant.id,'','Ошибка на сайте: '+pw.errMesage);
				removeOrder(webApplicant);
				webApplicant=null;
				//to prevent cycle web check when network error or offline
				if(webErrCounter>WEB_ERRORS_LIMIT){
					flowError('Ошибка web: '+pw.errMesage);
				}
				checkQueueLate();
				return;
			}
			webErrCounter=0;
			var siteState:int=OrderLoad.REMOTE_STATE_NONE;
			var err:String='';
			if(webApplicant.extraInfo){
				var frwState:int=AliasForward.forvardState(webApplicant.extraInfo.calcAlias);
				if(frwState>0){
					trace('onGetOrderInfo; forward order '+webApplicant.id +' to state '+frwState.toString());
					webApplicant.state=OrderState.FTP_COMPLETE;
					siteState=OrderLoad.REMOTE_STATE_DONE;
					StateLog.log(OrderState.FTP_COMPLETE,webApplicant.id,'','calc_alias: '+webApplicant.extraInfo.calcAlias +' ('+frwState.toString()+')');
				}
			}
			if(siteState!=OrderLoad.REMOTE_STATE_DONE){
				siteState=OrderLoad.REMOTE_STATE_ERROR;
				webApplicant.state=OrderState.FTP_INCOMPLITE;
				err='Пустой список файлов на сайте';
				trace('onGetOrderInfo web order err: Пустой список файлов');
				StateLog.log(OrderState.ERR_GET_PROJECT,webApplicant.id,'',err);
			}
			
			webApplicant.saveState();
			webApplicant.src_state=siteState.toString();
			webApplicant.files=null;
			setOrderStateWeb(webApplicant,siteState,err,pw);
			//save in bd
			var latch:DbLatch= new DbLatch(true);
			latch.addLatch(bdService.save(OrderLoad.fromOrder(webApplicant),0));
			latch.start();
			removeOrder(webApplicant);
			webApplicant=null;
			checkQueue();
		}

		private function setOrderStateWeb(order:Order, remoteState:int, comment:String='', webService:BaseWeb=null):void{
			if(!order) return;
			if(!webService) webService=WebServiceBuilder.build(source);
			downloadCaption='Смена статуса на сайте ' +order.id +' = '+remoteState.toString();
			var ord:Order=new Order();
			ord.id=order.id;
			ord.src_id=order.src_id;
			ord.src_state=remoteState.toString();
			ord.errStateComment=comment;
			webService.addEventListener(Event.COMPLETE,onSetOrderStateWeb);
			webService.setLoaderOrderState(ord);
		}

		private function onSetOrderStateWeb(e:Event):void{
			var pw:BaseWeb=e.target as BaseWeb;
			pw.removeEventListener(Event.COMPLETE,onSetOrderStateWeb);

			if(pw.hasError){
				webErrCounter++;
				trace('setOrderStateWeb web err: '+pw.errMesage);
				//if(webStatelatch && webStatelatch.isStarted) webStatelatch.releaseError('Ошибка сайта: '+pw.errMesage);
				if(pw.lastOrderId){
					lastError='Ошибка сайта '+pw.lastOrderId+' :'+pw.errMesage;
					StateLog.log(OrderState.ERR_WEB,pw.lastOrderId,'','Ошибка сайта: '+pw.errMesage);
				}
				if(webApplicant && webApplicant.id==pw.lastOrderId){
					webApplicant.state=OrderState.ERR_WEB;
					webApplicant=null;
					//checkQueueLate();
				}
			}else{
				if(webApplicant && webApplicant.id==pw.lastOrderId && webApplicant.state==OrderState.FTP_WEB_CHECK){
					webApplicant.state=OrderState.FTP_CAPTURED;
					webApplicant.saveState();
					webApplicant.src_state=OrderLoad.REMOTE_STATE_COPY.toString();
					var latch:DbLatch= new DbLatch(true);
					latch.addEventListener(Event.COMPLETE, onOrderMerged);
					latch.addLatch(bdService.merge(OrderLoad.fromOrder(webApplicant),0));
					latch.start();
					if(!isStarted || forceStop) webApplicant=null;
				}
			}
		}

		private function onOrderMerged(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,onOrderMerged);
			if(!webApplicant || !isStarted || forceStop) return;
			if(!latch.complite){
				//hz
				webApplicant=null;
				return;
			}
			//get merged files
			if(latch.lastDataItem as OrderLoad) webApplicant.files=(latch.lastDataItem as OrderLoad).files as ArrayCollection;
			//list ftp 
			startList();
		}
		
		private function startList():void{
			if(!webApplicant || !isStarted || forceStop) return;
			trace('Start list ' +webApplicant.id+' '+webApplicant.ftp_folder);
			if(!webApplicant.ftp_folder){
				webApplicant.state=OrderState.ERR_LOAD;
				trace('empty ftp_folder '+webApplicant.id);
				StateLog.log(OrderState.ERR_LOAD,webApplicant.id, '', 'Папка заказа не определена');
				webApplicant=null;
				checkQueueLate();
				return;
			}
			downloadCaption='Список файлов ' +webApplicant.id;
			webApplicant.state=OrderState.FTP_LIST;
			StateLog.log(OrderState.FTP_LIST,webApplicant.id);
			var ftpList:FTPList= new FTPList(source);
			ftpList.addEventListener(Event.COMPLETE, onFtpList);
			ftpList.list(webApplicant.ftp_folder);
		}
		
		private function onFtpList(evt:Event):void{
			var ftp:FTPList=evt.target as FTPList;
			var listing:Array;
			if(!ftp) return;
			ftp.removeEventListener(Event.COMPLETE, onFtpList);
			if(!webApplicant || !isStarted || forceStop) return;

			if(ftp.hasError){
				webApplicant.state=OrderState.ERR_LOAD;
				trace('List error ' +webApplicant.id+'; '+ftp.errMesage);
				StateLog.log(OrderState.ERR_LOAD,webApplicant.id, '', ftp.errMesage);
				webApplicant=null;
				checkQueueLate();
				return;
			}else{
				StateLog.log(webApplicant.state,webApplicant.id, '', 'FTP list complite');
			}
			listing=ftp.listing;
			//check listing
			var err:String='';
			var chkErr:Boolean=false;
			if(!webApplicant.files || !listing || listing.length<webApplicant.files.length){
				chkErr=true;
				err='Не соответствие количества файлов';
			}else{
				var of:OrderFile;
				var ftpfile:FTPFile;
				for each(of in webApplicant.files){
					//of.state=OrderState.FTP_WAITE;
					ftpfile=ArrayUtil.searchItem('name',of.file_name,listing) as FTPFile;
					if(!ftpfile){
						chkErr=true;
						if(err) err=err+',';
						err=err+of.file_name;
						of.state=OrderState.ERR_GET_PROJECT;
					}else{
						ftpfile.data=of;
					}
				}
				if(chkErr) err='Нет файла на фтп '+err;
			}
			if(chkErr){
				trace('List error ' +webApplicant.id+'; '+err);
				StateLog.log(OrderState.ERR_GET_PROJECT,webApplicant.id, '', err);
				webApplicant.state=OrderState.FTP_INCOMPLITE;
				webApplicant.src_state=OrderLoad.REMOTE_STATE_ERROR.toString();
				setOrderStateWeb(webApplicant,OrderLoad.REMOTE_STATE_ERROR,err);
				var latch:DbLatch= new DbLatch(true);
				latch.addEventListener(Event.COMPLETE,onSave);
				latch.addLatch(bdService.merge(OrderLoad.fromOrder(webApplicant),OrderState.FTP_CAPTURED),webApplicant.id);
				latch.start();
				removeOrder(webApplicant);
				webApplicant=null;
				checkQueueLate();
				return;
			}
			//start download
			webApplicant.ftpQueue=listing;
			webApplicant.state=OrderState.FTP_LOAD;
			//StateLog.log(OrderState.FTP_LOAD,webApplicant.id);
			startDownload(webApplicant);
			webApplicant=null;
		}

		private function onSave(evt:Event):void{
			var latch:DbLatch=evt.target as DbLatch;
			if(latch){
				latch.removeEventListener(Event.COMPLETE, onSave);
				if(!latch.complite){
					if(latch.lastErrCode==OrderState.ERR_WRONG_STATE && latch.lastTag){
						StateLog.log(OrderState.ERR_WRONG_STATE,latch.lastTag,'',latch.lastError);
					}
				}
			}
		}
		
		private function startDownload(order:Order):void{
			//remove from queue
			//removeOrder(order);
			downloadCaption='Старт загрузки ' +order.id;
			downloadManager.download(order);
		}
		
		private function checkQueueLate():void{
			if(!webTimer){
				webTimer= new Timer(RESTART_TIMEOUT);
				webTimer.addEventListener(TimerEvent.TIMER,onWebTimer);
			}else{
				webTimer.reset();
			}
			webTimer.start();
		}
		private function onWebTimer(evt:Event):void{
			if(downloadManager.needOrder) checkQueue();
		}

		private function onDownloadManagerNeedOrder(event:ImageProviderEvent):void{
			if(ORDERS_INPROCESS_LIMIT>0){
				var inprocess:int=0;
				if(downloadManager) inprocess+=downloadManager.queueLenth;
				if(webApplicant) inprocess++;
				
				if(inprocess>=ORDERS_INPROCESS_LIMIT) return;
			}
			checkQueue();
		}
		
		private function onDownloadManagerLoadFile(event:ImageProviderEvent):void{
			//save file state
			if(event.ftpFile){
				var of:OrderFile=event.ftpFile.data as OrderFile;
				if(of){
					of.state=OrderState.FTP_WAITE_CHECK;
					var latch:DbLatch=new DbLatch(true);
					latch.addLatch(bdService.saveFile(of));
					latch.start();
				}
			}
		}
		
		private function onDownloadManagerLoad(event:ImageProviderEvent):void{
			var order:Order=event.order;
			if(order) order.saveState();
			removeOrder(order);

			dispatchEvent(event.clone());
			//dispatchEvent(new Event('queueLenthChange'));
		}

		protected function onDownloadFault(event:ImageProviderEvent):void{
			//some fatal error
			var order:Order=event.order;
			if(order){
				if(order.state>=0){
					order.state=OrderState.ERR_LOAD;
					StateLog.log(OrderState.ERR_LOAD,order.id,'',event.error);
				}
				//????
				order.setErrLimit();
				resetOrder(order);
				//queue.push(order);
				//dispatchEvent(new Event('queueLenthChange'));
			}

		}

		protected function resetOrder(order:Order):void{
			if(!order) return;
			order.printGroups=new ArrayCollection();
			order.suborders=new ArrayCollection();
			order.ftpQueue=[];
		}

		protected function resetOrderState(order:Order):void{
			if(!order) return;
			if(order.state==OrderState.ERR_CHECK_MD5) return;
			order.restoreState();
		}

		/*
		protected function getOrderById(orderId:String, pop:Boolean=false):Order{
			var result:Order;
			var idx:int;
			if(pop){
				var arr:Array=queue.source;
				idx=ArrayUtil.searchItemIdx('id', orderId, arr);
				if(idx!=-1){
					var o:Object=arr.splice(idx,1)[0];
					result=o as Order;
					queue.refresh();
				}
				dispatchEvent(new Event('queueLenthChange'));
			}else{
				result=ArrayUtil.searchItem('id', orderId, queue.source) as Order;
			}
			
			return result;
		}
		*/

		protected function removeOrder(order:Order):void{
			if(!order || !queue) return;
			//var idx:int=queue.indexOf(order);
			var arr:Array=queue.source;
			var idx:int=ArrayUtil.searchItemIdx('id', order.id, arr);
			if(idx!=-1) arr.splice(idx,1);
			//queue.refresh();
			queue= new ArrayCollection(arr);
			dispatchEvent(new Event('queueLenthChange'));
		}

		protected function onFlowErr(evt:ImageProviderEvent):void{
			flowError(evt.error);
		}
		
		protected function flowError(errMsg:String):void{
			lastError=errMsg;
			dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,errMsg));
		}

		private var ftpSpeed:Number=0;
		private function onLoadProgress(evt:LoadProgressEvent):void{
			downloadCaption=evt.caption;
			ftpSpeed=evt.speed;
			speed=ftpSpeed;
			//if(fbDownloadManager) speed+=fbDownloadManager.speed;
			dispatchEvent(evt.clone());
		}
		
		private function onConnProgress(evt:ConnectionsProgressEvent):void{
			connectionsActive=evt.active;
			connectionsFree=evt.free;
			connectionsPending=evt.pending;
		}
		
	}
}