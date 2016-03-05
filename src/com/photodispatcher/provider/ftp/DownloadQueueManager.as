package com.photodispatcher.provider.ftp{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.ConnectionsProgressEvent;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.event.LoadProgressEvent;
	import com.photodispatcher.factory.OrderBuilder;
	import com.photodispatcher.factory.SuborderBuilder;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.mysql.DbLatch;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.services.OrderService;
	import com.photodispatcher.provider.fbook.download.FBookDownloadManager;
	import com.photodispatcher.service.web.BaseWeb;
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
	
	[Event(name="progress", type="flash.events.ProgressEvent")]
	[Event(name="orderLoaded", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="flowError", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="loadFault", type="com.photodispatcher.event.ImageProviderEvent")]
	public class DownloadQueueManager extends EventDispatcher{
		public static const RESTART_TIMEOUT:int=10000;
		public static const PRODUCTION_ERR_RESET_DELAY:int=1000*60*3;
		public static const WEB_ERRORS_LIMIT:int=3;
		
		protected var _isStarted:Boolean=false;
		protected var forceStop:Boolean;
		
		protected var _source:Source;
		public function get source():Source{
			return _source;
		}

		/*
		*orders Queue
		*/
		protected var queue:Array=[];
		protected var localFolder:String;
		
		private var downloadManager:FTPDownloadManager;
		[Bindable]
		public var fbDownloadManager:FBookDownloadManager;
		private var webTimer:Timer;
		private var webErrCounter:int=0;
		private var webApplicant:Order;
		
		public function DownloadQueueManager(source:Source=null){
			super(null);
			_source=source;
			if(this.source) sourceCaption=this.source.name;
			if(source && source.ftpService) connectionsLimit=source.ftpService.connections;
		}
		
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
			//check config production
			if(source.type==SourceType.SRC_FOTOKNIGA && Context.getProduction()==0){
				flowError('Не назначено производство');
				return;
			}
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
			
			//prt folder
			dstFolder=Context.getAttribute('prtPath');
			if(!dstFolder){
				Context.setAttribute('prtPath',Context.getAttribute('workFolder'));
			}else{
				file=new File(dstFolder);
				if(!file.exists || !file.isDirectory){
					flowError('Не задана папка подготовленных заказов');
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
			}
			
			//reset runtime states
			for each(var order:Order in queue){
				if(order){
					if(order.state==OrderState.FTP_WEB_CHECK || order.state==OrderState.FTP_WEB_OK){
						resetOrderState(order);
					}
					//reset errors
					if(order.state<0 && order.state!=OrderState.ERR_WRITE_LOCK){
						resetOrder(order);
						resetOrderState(order);
					}
				}
			}

			trace('QueueManager starting for '+source.ftpService.url);
			_isStarted=true;
			forceStop=false;
			dispatchEvent(new Event('isStartedChange'));

			//start fbook download
			if(!fbDownloadManager && source.hasFbookService){
				fbDownloadManager= new FBookDownloadManager(source);
				//listen
				fbDownloadManager.addEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onFBDownloadManagerLoad);
				fbDownloadManager.addEventListener(ImageProviderEvent.LOAD_FAULT_EVENT,onDownloadFault);
				fbDownloadManager.addEventListener(ProgressEvent.PROGRESS,onFBLoadProgress);
				fbDownloadManager.addEventListener(ImageProviderEvent.FLOW_ERROR_EVENT,onFlowErr);
			}
			if(fbDownloadManager) fbDownloadManager.start();
			
			//start ftp download
			if(!downloadManager){
				downloadManager= new FTPDownloadManager(source);
				//listen
				downloadManager.addEventListener(ImageProviderEvent.FETCH_NEXT_EVENT,onDownloadManagerNeedOrder);
				//downloadManager.addEventListener(ImageProviderEvent.FLOW_ERROR_EVENT,onDownloadManagerFlowError);
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

		public function clearCache():void{
			if(fbDownloadManager) fbDownloadManager.clearCache();
		}
		
		public function destroy():void{
			if(isStarted) stop();
			if(downloadManager){
				downloadManager.removeEventListener(ImageProviderEvent.FETCH_NEXT_EVENT,onDownloadManagerNeedOrder);
				//downloadManager.removeEventListener(ImageProviderEvent.FLOW_ERROR_EVENT,onDownloadManagerFlowError);
				downloadManager.removeEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onDownloadManagerLoad);
				downloadManager.removeEventListener(ImageProviderEvent.LOAD_FAULT_EVENT,onDownloadFault);
				downloadManager.removeEventListener(ProgressEvent.PROGRESS,onLoadProgress);
				downloadManager.removeEventListener(ConnectionsProgressEvent.CONNECTIONS_PROGRESS_EVENT, onConnProgress);
				//downloadManager.removeEventListener(SpeedEvent.SPEED_EVENT, onSpeed);
				downloadManager.removeEventListener(ImageProviderEvent.FLOW_ERROR_EVENT,onFlowErr);
				downloadManager.destroy();
				downloadManager=null;
			}
			if(fbDownloadManager){
				//stop listen
				fbDownloadManager.removeEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onFBDownloadManagerLoad);
				fbDownloadManager.removeEventListener(ImageProviderEvent.LOAD_FAULT_EVENT,onDownloadFault);
				//fbDownloadManager.removeEventListener(ProgressEvent.PROGRESS,onFBLoadProgress);
				fbDownloadManager.removeEventListener(ImageProviderEvent.FLOW_ERROR_EVENT,onFlowErr);
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
			//TODO close 4 debug
			if(fbDownloadManager) stopedOrders=stopedOrders.concat(fbDownloadManager.stop());
			
			//reset stoped
			for each(order in stopedOrders){
				if(order){
					releaseLock(order.id);
					resetOrder(order);
					resetOrderState(order);	
					queue.unshift(order);
				}
			}
			
			//uncapture stoped orders
			if(stopedOrders.length>0){
				var latch:DbLatch= new DbLatch(true);
				var orderService:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
				//latch.addEventListener(Event.COMPLETE,oncaptureState);
				latch.addLatch(orderService.setStateBatch(new ArrayCollection(stopedOrders)));
				latch.start();
			}
			
			//reset runtime states
			for each(order in queue){
				if(order){
					if(order.state==OrderState.FTP_WEB_CHECK || order.state==OrderState.FTP_WEB_OK){
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
			//empty responce from DAO?
			if(!orders) return;
			
			//TODO ??????
			if(webTimer) webTimer.stop();
			webErrCounter=0;
			
			//reSync in fbook download first
			if(fbDownloadManager) fbDownloadManager.reSync(orders);
			//reSync in download first
			if(downloadManager) downloadManager.reSync(orders);
			//apply resync filter
			var syncOrders:Array=orders.filter(reSyncFilter);
			if(syncOrders.length==0){
				//nothig to process
				//clear queue
				queue=[];
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
			for each (order in queue){
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
							//del old from queue
							toKill.push(order);
						}else if(source.type==SourceType.SRC_FOTOKNIGA && Context.getProduction()!=Context.PRODUCTION_ANY && order.state==OrderState.CANCELED_PRODUCTION){
							//del from queue, recheck production
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
				if(order){
					removeOrder(order);
					/*
					idx=ArrayUtil.searchItemIdx('id',order.id,queue);
					if(idx!=-1) queue.splice(idx,1);
					*/
				}
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
					queue.push(order);
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
			return o!=null && source && o.source==source.id && o.state==OrderState.FTP_WAITE;
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

		public function fetchNext():Order{
			var order:Order=fetch(true);
			if (!order) return null;
			//remove from queue
			removeOrder(order);
			dispatchEvent(new Event('queueLenthChange'));
			return order;
		}

		public function unFetch(order:Order):void{
			if (!order) return;
			//resetOrderState(order);
			resetOrder(order);
			queue.unshift(order);
			dispatchEvent(new Event('queueLenthChange'));
			if(isStarted && downloadManager && !downloadManager.isRunning) checkQueue();
		}

		protected function fetch(forceReset:Boolean=false):Order{
			var newOrder:Order;
			var ord:Order;
			//chek queue
			for each (ord in queue){
				if(ord && !ord.exceedErrLimit){
					if((forceReset) && ord.state<0 && ord.state!=OrderState.ERR_WRITE_LOCK) resetOrderState(ord);
					if(ord.state==OrderState.ERR_PRODUCTION_NOT_SET || ord.state==OrderState.ERR_LOCK_FAULT){
						var dt:Date= new Date();
						if((dt.time-ord.state_date.time)>PRODUCTION_ERR_RESET_DELAY)  resetOrderState(ord);
					}
					if(ord.state>0){
						//if(ord.state==OrderState.FTP_WEB_CHECK) ord.state=ord.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
						//if(ord.state==OrderState.FTP_WEB_OK && ord.id!=listOrderId) ord.state=ord.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
						if(ord.state==OrderState.FTP_WAITE || ord.state==OrderState.FTP_FORWARD){
							if(!newOrder){
								newOrder=ord;
							}else if(!newOrder.ftpForwarded && ord.ftpForwarded){
								newOrder=ord;
							}
						}
					}else if(ord.state!=OrderState.ERR_WRITE_LOCK && ord.state!=OrderState.ERR_PRODUCTION_NOT_SET && ord.state!=OrderState.ERR_LOCK_FAULT){
						//reset error
						//ord.state=ord.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
						resetOrderState(ord);
					}
				}
			}
			return newOrder;
		}
		
		private var webService:BaseWeb;
		
		private function checkQueue():void{
			if(webApplicant || !isStarted || forceStop) return;
			var newOrder:Order=fetch();
			if(newOrder && !webApplicant){
				webApplicant=newOrder;
				getLock();
				/*
				webApplicant.state=OrderState.FTP_WEB_CHECK;
				if(!webService) webService=WebServiceBuilder.build(source);
				//var w:BaseWeb= WebServiceBuilder.build(source);
				webService.addEventListener(Event.COMPLETE,getOrderHandle);
				webService.getOrder(newOrder);
				*/
			}
		}
		
		private function getLock():void{
			if(!webApplicant || !isStarted || forceStop) return;
			trace('QueueManager.getLock '+webApplicant.id);
			var latch:DbLatch=OrderService.getLoadLock(webApplicant.id);
			latch.addEventListener(Event.COMPLETE,ongetLock);
			latch.start();
		}
		private function ongetLock(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			latch.removeEventListener(Event.COMPLETE,ongetLock);
			if(!webApplicant || !isStarted || forceStop) return;
			if(latch.resultCode>0){
				StateLog.log(webApplicant.state, webApplicant.id,'','Получена мягкая блокировка ' + Context.appID);
				checkWebState();
			}else{
				lastError='Заказ '+webApplicant.id+' обрабатывается на другой станции';
				trace('QueueManager.getLock fault '+webApplicant.id);
				//StateLog.log(OrderState.ERR_LOCK_FAULT, webApplicant.id,'','soft lock');
				webApplicant.state= OrderState.ERR_LOCK_FAULT;
				webApplicant=null;
				checkQueue();
			}
		}
		
		private function releaseLock(orderId:String):void{
			if(!orderId) return;
			OrderService.releaseLoadLock(orderId);
		}

		private function checkWebState():void{
			//check state on site
			if(!webApplicant || !isStarted || forceStop) return;
			trace('QueueManager.checkWebState '+webApplicant.ftp_folder);
			webApplicant.state=OrderState.FTP_WEB_CHECK;
			if(!webService) webService=WebServiceBuilder.build(source);
			webService.addEventListener(Event.COMPLETE,getOrderHandle);
			webService.getOrder(webApplicant);
		}
		
		
		private function getOrderHandle(e:Event):void{
			var pw:BaseWeb=e.target as BaseWeb;
			pw.removeEventListener(Event.COMPLETE,getOrderHandle);
			if(!webApplicant) return;
			/*
			var startOrder:Order=getOrderById(webApplicant.id);
			webApplicant=null;
			*/

			if(!webApplicant || webApplicant.state!=OrderState.FTP_WEB_CHECK){
				//removed from queue or some else
				//check next
				checkQueue();
				return;
			}
			
			if(pw.hasError){
				trace('getOrderHandle web check order err: '+pw.errMesage);
				webErrCounter++;
				webApplicant.state=OrderState.ERR_WEB;
				releaseLock(webApplicant.id);
				StateLog.log(OrderState.ERR_WEB,webApplicant.id,'','Ошибка проверки на сайте: '+pw.errMesage);
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
			if(pw.isValidLastOrder(true)){
				//check production
				if(source.type==SourceType.SRC_FOTOKNIGA && Context.getProduction()!=Context.PRODUCTION_ANY){
					webApplicant.production=pw.getLastOrder().production;
					if(webApplicant.production==Context.PRODUCTION_NOT_SET){
						trace('QueueManager.getOrderHandle; order production not set '+webApplicant.id);
						webApplicant.state=OrderState.ERR_PRODUCTION_NOT_SET;
						webApplicant=null;
						//releaseLock(startOrder);
						checkQueue();
						return;
					}
					if(webApplicant.production!=Context.getProduction()){
						trace('QueueManager.getOrderHandle; wrong order production; cancel order '+webApplicant.id);
						webApplicant.state=OrderState.CANCELED_PRODUCTION;
						webApplicant=null;
						//TODO save && remove from queue ??
						/*
						removeOrder(startOrder);
						*/
						//releaseLock(startOrder);
						checkQueue();
						return;
					}
				}
				//open cnn & get files list
				trace('QueueManager.getOrderHandle; web check Ok; push to download manager '+webApplicant.ftp_folder);
				webApplicant.state=OrderState.FTP_WEB_OK;
				if(!webApplicant.ftp_folder) webApplicant.ftp_folder=webApplicant.id;

				//fill extra info ???
				if(pw.getLastOrder().extraInfo) webApplicant.extraInfo=pw.getLastOrder().extraInfo;

				//capture for load
				trace('QueueManager.getOrderHandle: captureState order '+webApplicant.id);
				webApplicant.state=OrderState.FTP_CAPTURED;
				var latch:DbLatch= new DbLatch(true);
				var orderService:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
				latch.addEventListener(Event.COMPLETE,oncaptureState);
				latch.addLatch(orderService.captureState(webApplicant.id, OrderState.FTP_WAITE, OrderState.FTP_CAPTURED, Context.appID),webApplicant.id);
				latch.start();
				/*
				//remove from queue
				removeOrder(startOrder);
				downloadManager.download(startOrder);
				dispatchEvent(new Event('queueLenthChange'));
				*/
				return;
			}else{
				//mark as canceled
				trace('QueueManager.getOrderHandle; web check fault; order canceled '+webApplicant.ftp_folder);
				webApplicant.state=OrderState.CANCELED_SYNC;
				flowError('Заказ отменен: '+webApplicant.id);
				releaseLock(webApplicant.id);
				webApplicant=null;
				checkQueue();
				return;
			}
		}
		
		private function oncaptureState(evt:Event):void{
			var latch:DbLatch= evt.target as DbLatch;
			if(!latch) return;
			latch.removeEventListener(Event.COMPLETE,oncaptureState);
			releaseLock(latch.lastTag);

			if(!webApplicant || !isStarted || forceStop) return;
			var startOrder:Order=webApplicant;
			webApplicant=null;

			if (latch.complite && latch.resultCode==OrderState.FTP_CAPTURED){
				//download
				StateLog.log(startOrder.state, startOrder.id,'','Получена жесткая блокировка ' + Context.appID);
				startDownload(startOrder);
			}else{
				trace('QueueManager.captureState: db error '+latch.lastError);
				lastError='Заказ: '+startOrder.id+' блокирован другим процессом '+latch.lastError;
				//StateLog.log(OrderState.ERR_LOCK_FAULT, startOrder.id,'','hard lock');
				startOrder.state= OrderState.ERR_LOCK_FAULT;
				checkQueue();
			}
		}

		protected function unCaptureOrder(orderId:String):void{
			if(!orderId) return;
			var o:Order= new Order();
			o.id=orderId;
			o.state=OrderState.FTP_WAITE;
			var latch:DbLatch= new DbLatch(true);
			var orderService:OrderService=Tide.getInstance().getContext().byType(OrderService,true) as OrderService;
			//latch.addEventListener(Event.COMPLETE,oncaptureState);
			latch.addLatch(orderService.setState(o));
			latch.start();
		}

		
		private function startDownload(order:Order):void{
			//remove from queue
			removeOrder(order);
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
			checkQueue();
		}

		private function onDownloadManagerNeedOrder(event:ImageProviderEvent):void{
			checkQueue();
		}

		/*
		private function onDownloadManagerFlowError(event:ImageProviderEvent):void{
			flowError(event.error);
		}
		*/
		
		private function onDownloadManagerLoad(event:ImageProviderEvent):void{
			//parse suborders
			var order:Order=event.order;
			var err:String=SuborderBuilder.buildFromFileSystem(source,order);
			if(err){
				if(order){
					order.state=OrderState.ERR_FILE_SYSTEM;
					StateLog.log(order.state,order.id,'',err);
					order.setErrLimit();
					resetOrder(order);
					queue.push(order);
					dispatchEvent(new Event('queueLenthChange'));
				}
			}else if(order.hasSuborders){
				if(!fbDownloadManager){
					//dispatchEvent(event.clone());
					//fbookservice not configured
					trace('QueueManager.onDownloadManagerLoad; fbook service not configured; order id '+order.id);
					order.state=OrderState.ERR_GET_PROJECT;
					StateLog.log(OrderState.ERR_GET_PROJECT,order.id,'','Сервис Fbook не настроен');
					order.setErrLimit();
					resetOrder(order);
					queue.push(order);
				}else{
					fbDownloadManager.download(order);
				}
			}else{
				//complited
				//save to filesystem
				var state:int=OrderBuilder.saveToFilesystem(order);
				if(state<0){
					//some error
					order.state=state;
					StateLog.log(state,order.id,'','Ошибка сохранеия в рабочую папку (OrderBuilder.saveToFilesystem)');
					resetOrder(order);
					queue.push(order);
					return;
				}
				dispatchEvent(event.clone());
			}
		}

		private function onFBDownloadManagerLoad(event:ImageProviderEvent):void{
			//complited
			var order:Order=event.order;
			//save to filesystem
			var state:int=OrderBuilder.saveToFilesystem(order);
			if(state<0){
				//some error
				order.state=state;
				StateLog.log(state,order.id,'','Ошибка сохранеия в рабочую папку (OrderBuilder.saveToFilesystem)');
				resetOrder(order);
				queue.push(order);
				return;
			}
			dispatchEvent(event.clone());
		}

		protected function onDownloadFault(event:ImageProviderEvent):void{
			//some fatal error
			var order:Order=event.order;
			if(order){
				unCaptureOrder(order.id);
				if(order.state>=0){
					order.state=OrderState.ERR_FTP;
					StateLog.log(OrderState.ERR_FTP,order.id,'',event.error);
				}
				order.setErrLimit();
				resetOrder(order);
				queue.push(order);
				dispatchEvent(new Event('queueLenthChange'));
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
			order.state=order.ftpForwarded?OrderState.FTP_FORWARD:OrderState.FTP_WAITE;
		}

		protected function getOrderById(orderId:String, pop:Boolean=false):Order{
			var result:Order;
			var idx:int;
			if(pop){
				idx=ArrayUtil.searchItemIdx('id', orderId, queue);
				if(idx!=-1){
					var o:Object=queue.splice(idx,1)[0];
					result=o as Order;
				}
				dispatchEvent(new Event('queueLenthChange'));
			}else{
				result=ArrayUtil.searchItem('id', orderId, queue) as Order;
			}
			
			return result;
		}

		protected function removeOrder(order:Order):void{
			if(!order || !queue) return;
			var idx:int=queue.indexOf(order);
			if(idx!=-1) queue.splice(idx,1);
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
			if(fbDownloadManager) speed+=fbDownloadManager.speed;
			dispatchEvent(evt.clone());
		}
		
		private function onFBLoadProgress(evt:ProgressEvent):void{
			speed=ftpSpeed+fbDownloadManager.speed;
		}
		
		private function onConnProgress(evt:ConnectionsProgressEvent):void{
			connectionsActive=evt.active;
			connectionsFree=evt.free;
			connectionsPending=evt.pending;
		}
		
	}
}