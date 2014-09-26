package com.photodispatcher.provider.ftp{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.ConnectionsProgressEvent;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.event.LoadProgressEvent;
	import com.photodispatcher.factory.PrintGroupBuilder;
	import com.photodispatcher.factory.SuborderBuilder;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.PrintGroup;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceSvc;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Alert;
	
	import pl.maliboo.ftp.FTPFile;
	import pl.maliboo.ftp.events.FTPEvent;

	[Event(name="orderLoaded", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="flowError", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="fetchNext", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="loadFault", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="progress", type="com.photodispatcher.event.LoadProgressEvent")]
	[Event(name="connectionsProgress", type="com.photodispatcher.event.ConnectionsProgressEvent")]
	public class FTPDownloadManager extends EventDispatcher{
		//public static const SPEED_METER_INTERVAL:int=10;//sek
		private static const DEBUG_TRACE:Boolean=false;

		protected var source:Source;
		protected var ftpService:SourceSvc;
		protected var _isStarted:Boolean=false;
		protected var localFolder:String;
		protected var forceStop:Boolean=false;
		protected var connectionManager:FTPConnectionManager;
		protected var downloadOrders:Array=[];
		private var listApplicant:Order;
		private var remoteMode:Boolean;

		public function FTPDownloadManager(source:Source, remoteMode:Boolean=false){
			super(null);
			this.source=source;
			localFolder=source.getWrkFolder();
			this.remoteMode=remoteMode;
		}

		public function get isStarted():Boolean{
			return _isStarted;
		}

		public function start():Boolean{
			//TODO reset state
			
			//check
			if(!source || (!source.ftpService && source.type!=SourceType.SRC_FBOOK_MANUAL)){
				flowError('Ошибка инициализации');
				return false;
			}
			ftpService=source.ftpService;
			//check lockal folder
			if(!localFolder){
				flowError('Не задана рабочая папка');
				return false;
			}
			var fl:File=new File(localFolder);
			if(!fl.exists || !fl.isDirectory){
				flowError('Не верная рабочая папка');
				return false;
			}
			
			if(!connectionManager){
				connectionManager= new FTPConnectionManager(source);
				connectionManager.addEventListener(Event.CONNECT, onConnect);
				connectionManager.addEventListener(ImageProviderEvent.FLOW_ERROR_EVENT, onFlowErr);
				connectionManager.addEventListener(ConnectionsProgressEvent.CONNECTIONS_PROGRESS_EVENT, onCnnProgress);
			}
			
			trace('FTPDownloadManager started '+ftpService.url);
			_isStarted=true;
			forceStop=false;
			//startMeter();
			checkQueue();
			return true;
		}

		/**
		 * 
		 * @return array stoped orders  
		 * 
		 */		
		public function stop():Array{
			trace('FTPDownloadManager stop '+ftpService.url);
			var result:Array=[];
			forceStop=true;
			_isStarted=false;
			//stop downloadOrders
			var order:Order;
			if(downloadOrders && downloadOrders.length>0){
				for each(order in downloadOrders){
					if(order){
						stopDownload(order.id);
						result.push(order);
					}
				}
			}
			if(DEBUG_TRACE) trace('FTPDownloadManager stoped '+result.length.toString()+' orders');
			downloadOrders=[];
			listApplicant=null;
			loadProgress();
			//stopMeter();

			return result;
		}
		
		public function destroy():void{
			if(isStarted) stop();
			if(connectionManager){
				connectionManager.removeEventListener(Event.CONNECT, onConnect);
				connectionManager.removeEventListener(ImageProviderEvent.FLOW_ERROR_EVENT, onFlowErr);
				connectionManager.removeEventListener(ConnectionsProgressEvent.CONNECTIONS_PROGRESS_EVENT, onCnnProgress);
				connectionManager=null;
			}
		}
		
		public function download(order:Order):void{
			if(order) trace('FTPDownloadManager added order '+order.id);
			if(order){
				downloadOrders.push(order);
			}
			checkQueue();
			loadProgress();
		}
		
		public function reSync(orders:Array):void{
			//TODO restart ???!!!
			trace('FTPDownloadManager reSync '+ftpService.url);
			//flushWriteQueue();
			//empty responce from DAO?
			if(!orders) return;
			var syncOrders:Array=orders.filter(reSyncFilter);
			var order:Order;
			
			if(syncOrders.length==0){
				//nothig to process
				//stop downloadOrders
				if(downloadOrders && downloadOrders.length>0){
					for each(order in downloadOrders){
						if(order) stopDownload(order.id);
					}
				}
				downloadOrders=[];
				listApplicant=null;
				loadProgress();
				checkQueue();
				return;
			}
			
			//keep current, remove if not in sync
			//var syncMap:Object= arrayToMap(syncOrders);
			var toKill:Array=[];
			var toReplace:Array=[];
			var idx:int;
			
			//check downloadOrders
			for each (order in downloadOrders){
				if(order){
					idx=ArrayUtil.searchItemIdx('id',order.id,syncOrders);
					if (idx!=-1){
						//replace in input arr
						toReplace.push(order);
					}else{
						toKill.push(order);
						//stop
						stopDownload(order.id);
						//reset listing
						if(listApplicant && listApplicant.id==order.id) listApplicant=null;
					}
				}
			}
			//remove
			for each (order in toKill){
				if(order){
					idx=ArrayUtil.searchItemIdx('id',order.id,downloadOrders);
					if(idx!=-1) downloadOrders.splice(idx,1);
				}
			}
			//replace
			for each (order in toReplace){
				if(order){
					idx=ArrayUtil.searchItemIdx('id',order.id,orders);
					if(idx!=-1) orders[idx]=order;
				}
			}
			
			loadProgress();
			checkQueue();
		}
		protected function reSyncFilter(element:*, index:int, arr:Array):Boolean {
			var o:Order=element as Order;
			//return o!=null && o.state==syncState;
			return o!=null && source && o.source==source.id && o.state==OrderState.WAITE_FTP;
		}
		/**
		 * 
		 *force stop all running order connections
		 * @param orderId
		 * 
		 */		
		private function stopDownload(orderId:String):void{
			if(!orderId) return;
			if(DEBUG_TRACE) trace('FTPDownloadManager stopDownload '+orderId);
			var arr:Array=connectionManager.stopDownload(orderId);
			var cnn:FtpTask;
			for each(cnn in arr){
				stopListen(cnn);
			}
		}

		private function stopListen(cnn:FtpTask):void{
			if(!cnn) return;
			cnn.removeEventListener(FTPEvent.SCAN_DIR,onList);
			cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onListFault);
			cnn.removeEventListener(FTPEvent.DOWNLOAD,onDownload);
			cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onDownloadFault);
			cnn.removeEventListener(FTPEvent.DISCONNECTED,onDownloadDisconnected);
			cnn.removeEventListener(FTPEvent.DISCONNECTED,onListDisconnected);

			//cnn.removeEventListener(ProgressEvent.PROGRESS, onProgress);
		}
		
		private function checkQueue():void{
			if(!isStarted || forceStop) return;

			switch(hasTask()){
				case -1:
					//ask for order
					if(DEBUG_TRACE) trace('FTPDownloadManager checkQueue ask for order '+ftpService.url);
					dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FETCH_NEXT_EVENT));
					break;
				case 1:
					//ask for connection
					if(DEBUG_TRACE) trace('FTPDownloadManager checkQueue ask for connection '+ftpService.url);
					connectionManager.connect();
					break;
				case 0:
					//skeep
					if(DEBUG_TRACE) trace('FTPDownloadManager checkQueue waite list complite '+ftpService.url);
					break;
			}
			/*
			if(!hasTask()){
				//ask for order
				if(DEBUG_TRACE) trace('FTPDownloadManager checkQueue ask for order '+ftpService.url);
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FETCH_NEXT_EVENT));
				return;
			}
			//ask for connection
			if(DEBUG_TRACE) trace('FTPDownloadManager checkQueue ask for connection '+ftpService.url);
			connectionManager.connect();
			*/
		}
		
		public function get isRunning():Boolean{
			return hasTask()!=-1;
		}
		
		private function hasTask():int{ //-1 need order, 0 list in process, 1 need connection
			if(!downloadOrders || downloadOrders.length==0) return -1;
			var order:Order;
			var ftpFile:FTPFile;
			var result:int=-1;
			for each(order in downloadOrders){
				if(order){
					if(order.state==OrderState.FTP_WEB_OK && result!=0) result=1;//cnn 4 list
					if(order.state<0 && !order.exceedErrLimit && result!=0) result=1;//cnn 4 list (reload)
					if(order.state==OrderState.FTP_LIST && !listApplicant) result=1;//cnn 4 list (list canceled)
					if(order.state==OrderState.FTP_LIST && listApplicant && listApplicant.id==order.id) result=0;//list in process (wait till comlite)
					if(order.state==OrderState.FTP_LOAD && order.ftpQueue){
						for each(ftpFile in order.ftpQueue){
							if(ftpFile){
								if(ftpFile.loadState==FTPFile.LOAD_WAIT) return 1;//cnn 4 load
								if(ftpFile.loadState==FTPFile.LOAD_ERR) return 1;//cnn 4 load //??? TODO add err counter & errLimit check
							}
						}
					}
				}
			}
			return result;
		}

		private function reuseConnection(cnn:FtpTask):void{
			if(!cnn) return;
			/*
			if(!startTask(cnn)){
				//ask for order
				if(DEBUG_TRACE) trace('FTPDownloadManager reuseConnection ask for order '+ftpService.url);
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FETCH_NEXT_EVENT));
			}
			*/
			startTask(cnn);
			/*if(!startTask(cnn))*/
			checkQueue();
		}

		private function startTask(connection:FtpTask=null):Boolean{
			if(!isStarted || forceStop) return false;
			var cnn:FtpTask
			if(connection){
				cnn=connection;
			}else{
				cnn=connectionManager.getConnection();
				if(!cnn) return false;
			}
			var listCandidate:Order;
			var order:Order;
			var ftpFile:FTPFile;
			var downloadApplicant:FTPFile;
			for each(order in downloadOrders){
				if(order){
					//reset states
					if(order.state<0 && !order.exceedErrLimit) order.state=OrderState.FTP_WEB_OK;
					if(order.state==OrderState.FTP_LIST && (!listApplicant || listApplicant.id!=order.id)) order.state=OrderState.FTP_WEB_OK;
					//scan
					if(!listApplicant && order.state==OrderState.FTP_WEB_OK) listCandidate=order;
					if(order.state==OrderState.FTP_LOAD && order.ftpQueue){
						for each(ftpFile in order.ftpQueue){
							if(ftpFile){
								if(ftpFile.loadState==FTPFile.LOAD_WAIT || ftpFile.loadState==FTPFile.LOAD_ERR){
									if(ftpFile.loadState==FTPFile.LOAD_ERR){
										//TODO add err counter & errLimit check
										ftpFile.loadState=FTPFile.LOAD_WAIT;
									}
									downloadApplicant=ftpFile;
									downloadApplicant.tag=order.id;
									break;
								}
							}
						}
					}
				}
			}
			var result:Boolean=false;
			if(downloadApplicant){
				//start download
				if(DEBUG_TRACE) trace('FTPDownloadManager startTask start download '+downloadApplicant.name);
				cnn.orderId=downloadApplicant.tag;
				cnn.addEventListener(FTPEvent.DOWNLOAD,onDownload);
				cnn.addEventListener(FTPEvent.INVOKE_ERROR,onDownloadFault);
				cnn.addEventListener(FTPEvent.DISCONNECTED,onDownloadDisconnected);
				//cnn.addEventListener(ProgressEvent.PROGRESS, onProgress);
				cnn.download(downloadApplicant,localFolder);
				result=true;
			}else if(listCandidate && !listApplicant && listCandidate.ftp_folder){
				//start list
				listApplicant=listCandidate;
				if(DEBUG_TRACE) trace('FTPDownloadManager startTask start list '+listApplicant.ftp_folder);
				listApplicant.state=OrderState.FTP_LIST;
				cnn.orderId=listApplicant.id;
				cnn.addEventListener(FTPEvent.SCAN_DIR,onList);
				cnn.addEventListener(FTPEvent.INVOKE_ERROR,onListFault);
				cnn.addEventListener(FTPEvent.DISCONNECTED,onListDisconnected);
				cnn.scanFolder(listApplicant.ftp_folder);
				result=true;
			}else{
				if(listCandidate && !listCandidate.ftp_folder && listCandidate.hasSuborders){
					//fbook order run suborders load
					order.state=OrderState.FTP_LOAD;
					checkDownload();
				}
				//release connection
				if(DEBUG_TRACE) trace('FTPDownloadManager startTask release connection '+ftpService.url);
				connectionManager.release(cnn);
			}
			return result;
		}

		private function onList(e:FTPEvent):void{
			var idx:int;
			var cnn:FtpTask=e.target as FtpTask;
			var order:Order=listApplicant;
			listApplicant=null;
			if(!cnn) return;
			stopListen(cnn);
			var orderId:String=cnn.orderId;
			if(DEBUG_TRACE) trace('FTPDownloadManager scan folder complited '+orderId);
			if(!orderId || !order){
				reuseConnection(cnn);
				return;
			}
			if(order.id!=orderId){
				//wrong list sequence, reset
				order.state=OrderState.FTP_WEB_OK;
				reuseConnection(cnn);
				return;
			}
			
			var fileStructure:Dictionary=cnn.getFileStructure();
			//check 4 empty fileStructure
			var fileStructureOk:Boolean=false;
			for (var key:String in fileStructure){
				if(key){
					fileStructureOk=true;
					break;
				}
			}
			if(!fileStructureOk){
				trace('FTPDownloadManager empty ftp folder '+orderId);
				order.state=OrderState.ERR_FTP;
				if(order.exceedErrLimit){
					if(!remoteMode) StateLog.log(OrderState.ERR_FTP,order.id,'','Пустой список файлов. Папка '+order.ftp_folder);
					if(!order.hasSuborders){
						//remove from download (double err)
						idx=downloadOrders.indexOf(order);
						if(idx!=-1) downloadOrders.splice(idx,1);
						dispatchEvent(new ImageProviderEvent(ImageProviderEvent.LOAD_FAULT_EVENT,order,'Пустой список файлов'));
					}else{
						//fbook order run suborders load
						order.resetErrCounter();
						order.state=OrderState.FTP_LOAD;
						checkDownload();
					}
				}
				loadProgress();
				//reuseConnection(cnn);
				//reconnect ftp
				connectionManager.reconnect(cnn);
				return;
			}
			//buid suborders
			//var soArr:Array;
			try{
				//soArr= 
				SuborderBuilder.build(source,fileStructure,order);
			}catch (e:Error){
				trace('FTPDownloadManager error while build suborders '+orderId);
				order.state=OrderState.ERR_READ_LOCK;
				if(DEBUG_TRACE && !remoteMode) StateLog.log(OrderState.ERR_READ_LOCK,order.id,'','Блокировка чтения при парсе подзаказов.');
				loadProgress();
				reuseConnection(cnn);
				return;
			}
			
			//build print groups 
			var pgBuilder:PrintGroupBuilder= new PrintGroupBuilder();
			var pgArr:Array;
			try{
				pgArr= pgBuilder.build(source,fileStructure,orderId);
			}catch (e:Error){
				trace('FTPDownloadManager error while build print group'+orderId);
				order.state=OrderState.ERR_READ_LOCK;
				if(DEBUG_TRACE && !remoteMode) StateLog.log(OrderState.ERR_READ_LOCK,order.id,'','Блокировка чтения при парсе групп печати.'); 
				loadProgress();
				reuseConnection(cnn);
				return;
			}
			
			var ftpQueue:Array=e.listing;
			var ff:FTPFile;
			
			/*
			//check content filter
			var cFilter:ContentFilter=Context.getAttribute('contentFilter') as ContentFilter;
			var pg:PrintGroup;
			if(pgArr && cFilter && cFilter.id!=0){
				for each(pg in pgArr){
					if(!cFilter.allowPrintGroup(pg)){
						pg.state=OrderState.SKIPPED;
						//remove files
						var newFtpQueue:Array=[];
						for each(ff in ftpQueue){
							if(ff.parentDir!=pg.path){
								newFtpQueue.push(ff);
							}
						}
						ftpQueue=newFtpQueue;
						if(!remoteMode) StateLogDAO.logState(pg.state ,order.id,pg.id ); 
					}
				}
			}
			*/
			//check/create order local folder
			var fl:File=new File(localFolder);
			
			//TODO check disk space
			var avail:Number=fl.spaceAvailable;
			var need:Number=0;
			for each(ff in ftpQueue){
				if(ff){
					need+=ff.size;
				}
			}
			if(need>=avail){
				Alert('Не достаточно места для загрузки заказа. '+localFolder);
			}
			
			fl=fl.resolvePath(order.ftp_folder);
			try{
				if(fl.exists){
					if(fl.isDirectory){
						fl.deleteDirectory(true);
					}else{
						fl.deleteFile();
					}
				}
				fl.createDirectory();
			}catch(err:Error){
				if(!remoteMode) StateLog.log(OrderState.ERR_FILE_SYSTEM,order.id,'','Папка: '+fl.nativePath+': '+err.message); 
				order.state=OrderState.ERR_FILE_SYSTEM;
				if(order.exceedErrLimit){
					//remove from download
					idx=downloadOrders.indexOf(order);
					if(idx!=-1) downloadOrders.splice(idx,1);
					dispatchEvent(new ImageProviderEvent(ImageProviderEvent.LOAD_FAULT_EVENT,order,err.message));
				}
				loadProgress();
				reuseConnection(cnn);
				return;
			}
			
			//can download
			order.local_folder=fl.parent.nativePath;
			order.printGroups=new ArrayCollection(pgArr);
			//order.suborders=new ArrayCollection(soArr);
			order.state=OrderState.FTP_LOAD;
			order.ftpQueue=ftpQueue;
			order.resetErrCounter();
			trace('FTPDownloadManager start download order '+order.ftp_folder+', printGroups:'+order.printGroups.length.toString()+', ftpQueue:'+order.ftpQueue.length.toString());
			if(order.ftpQueue && order.ftpQueue.length>0){
				if(!remoteMode) StateLog.log(OrderState.FTP_LOAD,order.id,'','Старт загрузки'); 
				loadProgress();
			}else{
				trace('FTPDownloadManager empty order '+order.ftp_folder);
				checkDownload();
			}
			if(DEBUG_TRACE) trace('FTPDownloadManager onList reuse connection '+orderId);
			reuseConnection(cnn);
		}
		private function onListDisconnected(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			var order:Order=listApplicant;
			listApplicant=null;
			stopListen(cnn);
			if(order){	
				order.state=OrderState.ERR_FTP;
				order.resetErrCounter();//not fatal
				if(DEBUG_TRACE && !remoteMode) StateLog.log(OrderState.ERR_FTP,order.id,'','Ошибка FTP LIST Disconnected '+order.ftp_folder);
			}
			connectionManager.reconnect(cnn);
		}
		private function onListFault(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			var order:Order=listApplicant;
			listApplicant=null;
			if(!cnn) return;
			stopListen(cnn);
			var orderId:String=cnn.orderId;
			trace('FTPDownloadManager scan folder fault '+orderId+'; err: '+(e.error?e.error.message:''));
			if(!orderId || !order){
				connectionManager.reconnect(cnn);
				return;
			}
			if(order.id!=orderId){
				//wrong list sequence, reset
				order.state=OrderState.FTP_WEB_OK;
				connectionManager.reconnect(cnn);
				return;
			}
			
			order.state=OrderState.ERR_FTP;
			order.resetErrCounter();//not fatal
			if(DEBUG_TRACE && !remoteMode) StateLog.log(OrderState.ERR_FTP,order.id,'','Ошибка FTP LIST "'+order.ftp_folder+'": ' + (e.error?e.error.message:''));
			connectionManager.reconnect(cnn);
		}

		private function onDownload(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			if(cnn){
				if(DEBUG_TRACE) trace('FTPDownloadManager file downloaded '+cnn.downloadFile.name);
				stopListen(cnn);
			}
			checkDownload();
			reuseConnection(cnn);
		}
		private function onDownloadFault(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			if(cnn){
				if(DEBUG_TRACE) trace('FTPDownloadManager download fault '+ cnn.downloadFile.fullPath);
				stopListen(cnn);
				if(DEBUG_TRACE && !remoteMode) StateLog.log(OrderState.ERR_FTP,cnn.orderId,'','Ошибка загрузки "'+cnn.downloadFile.name+'": '+(e.error?e.error.message:''));
			}
			reuseConnection(cnn);
			//TODO err limit????
		}
		private function onDownloadDisconnected(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			stopListen(cnn);
			if(cnn){
				cnn.downloadFile.loadState=FTPFile.LOAD_ERR;
				if(DEBUG_TRACE) trace('FTPDownloadManager download Disconnected '+ cnn.downloadFile.fullPath);
				if(DEBUG_TRACE && !remoteMode) StateLog.log(OrderState.ERR_FTP,cnn.orderId,'','Ошибка загрузки Disconnected '+cnn.downloadFile.name);
				connectionManager.reconnect(cnn);
			}
		}
		private function checkDownload():void{
			var order:Order;
			var complete:Array=[];
			for each(order in downloadOrders){
				if(order && order.state==OrderState.FTP_LOAD && order.isFtpQueueComplete){
					//completed
					complete.push(order);
				}
			}
			if(DEBUG_TRACE && complete.length) trace('FTPDownloadManager checkDownload complete orders '+complete.length.toString());
			var idx:int;
			for each(order in complete){
				if(order){
					//remove from download
					idx=downloadOrders.indexOf(order);
					if(idx!=-1) downloadOrders.splice(idx,1);
					order.state=OrderState.FTP_COMPLETE;
					order.resetErrCounter();
					if(!remoteMode) StateLog.log(order.state,order.id,'',''); 
					dispatchEvent(new ImageProviderEvent(ImageProviderEvent.ORDER_LOADED_EVENT,order));
				}
			}
			
			loadProgress();
		}

		private function loadProgress():void{
			var caption:String='';
			var orders:int=0;
			var total:int=0;
			var done:int=0;
			var order:Order;
			var bytesDone:Number=0;
			var speed:Number=0;
			var orderSpeed:Number=0;
			var now:Date=new Date();
			for each(order in downloadOrders){
				if(order){
					orders++;
					bytesDone=0;
					orderSpeed=0;
					if(caption) caption+=', ';
					caption+=order.src_id;
					//total files
					if(order.ftpQueue){
						total=total+order.ftpQueue.length;
						//done
						var ff:FTPFile;
						for each(ff in order.ftpQueue){
							if (ff && ff.loadState==FTPFile.LOAD_COMPLETE){
								bytesDone+=ff.size;
								done++;
							}
						}
						if(bytesDone && (now.time-order.state_date.time)>0){
							orderSpeed=bytesDone/((now.time-order.state_date.time)/1000);//byte /sek
							orderSpeed=Math.round(orderSpeed/1024);//Kb /sek
						}
					}
					speed+=orderSpeed;
				}
			}
			caption='Загрузка ('+orders.toString()+'): '+caption;
			//dispatchEvent(new SpeedEvent(speed));
			dispatchEvent(new LoadProgressEvent(caption,done,total,speed));
		}

		private function flowError(errMsg:String):void{
			dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,errMsg));
		}

		private function onFlowErr(event:ImageProviderEvent):void{
			flowError(event.error);
		}

		private function onConnect(event:Event):void{
			if(startTask()) checkQueue();
		}
		
		private function onCnnProgress(event:ConnectionsProgressEvent):void{
			dispatchEvent(event.clone());
		}

	}
}