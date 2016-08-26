package com.photodispatcher.provider.ftp_loader{
	import com.photodispatcher.event.ConnectionsProgressEvent;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.event.LoadProgressEvent;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderFile;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceSvc;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.provider.ftp.FTPConnectionManager;
	import com.photodispatcher.provider.ftp.FtpTask;
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
	[Event(name="fileLoaded", type="com.photodispatcher.event.ImageProviderEvent")]
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
		//private var listApplicant:Order;

		/*
		states
		FTP_LOAD - FTP_WAITE_CHECK 
		ERR_FILE_SYSTEM ERR_FTP
		*/
		public function FTPDownloadManager(source:Source){
			super(null);
			this.source=source;
			localFolder=source.getWrkFolder();
		}

		public function get isStarted():Boolean{
			return _isStarted;
		}

		public function get queueLenth():int{
			return downloadOrders?downloadOrders.length:0;
		}

		public function start():Boolean{
			//TODO reset state
			
			//check
			if(!source || !source.ftpService){
				flowError('Ошибка инициализации');
				return false;
			}
			ftpService=source.ftpService;
			//check lockal folder
			if(!localFolder){
				flowError('Не задана рабочая папка');
				return false;
			}
			var file:File=new File(localFolder);
			if(!file.exists || !file.isDirectory){
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
			if(order){
				trace('FTPDownloadManager added order '+order.id);
				//check if already in queue
				var idx:int=ArrayUtil.searchItemIdx('id',order.id,downloadOrders);
				if(idx==-1){
					downloadOrders.push(order);
					prepareDownload(order);
				}
			}
			checkDownload();
			checkQueue();
		}
		private function prepareDownload(order:Order):void{
			if(!order || !order.ftp_folder) return;
			
			//check/create order local folder
			var file:File=new File(localFolder);
			//check disk space
			var avail:Number=file.spaceAvailable;
			var need:Number=0;
			var ff:FTPFile;
			for each(ff in order.ftpQueue){
				if(ff) need+=ff.size;
			}
			if(need>=avail){
				//stop
				//Alert('Не достаточно места для загрузки заказа. '+localFolder);
				StateLog.log(OrderState.ERR_FILE_SYSTEM,order.id,'','Не достаточно места для загрузки заказа.'); 
				order.state=OrderState.ERR_FILE_SYSTEM;
				order.errStateComment='Не достаточно места для загрузки заказа.';
				order.setErrLimit();
				//checkDownload();
				return;
			}
			
			file=file.resolvePath(order.ftp_folder);
			try{
				if(file.exists && !file.isDirectory) file.deleteFile();
				file.createDirectory();
			}catch(err:Error){
				StateLog.log(OrderState.ERR_FILE_SYSTEM,order.id,'','Папка: '+file.nativePath+': '+err.message); 
				order.state=OrderState.ERR_FILE_SYSTEM;
				order.errStateComment=err.message;
				order.setErrLimit();
				//checkDownload();
				return;
			}

			//link order file && ftp file
			var of:OrderFile;
			var lf:File;
			if(order.files){
				for each(of in order.files){
					ff=ArrayUtil.searchItem('name',of.file_name, order.ftpQueue) as FTPFile;
					//if(ff) ff.data=of;
					//check loaded files
					lf=file.resolvePath(of.file_name);
					if(lf.exists){
						if(of.state>=OrderState.FTP_WAITE_CHECK){
							if(ff) ff.loadState=FTPFile.LOAD_COMPLETE;
						}else{
							try{
								lf.deleteFile();
							}catch(err:Error){}
						}
					}
				}
			}
			
			//can download
			//order.local_folder=file.parent.nativePath; //?parent
			order.state=OrderState.FTP_LOAD;
			order.resetErrCounter();
			trace('FTPDownloadManager start download order '+order.ftp_folder+', ftpQueue:'+order.ftpQueue.length.toString());
			if(order.ftpQueue && order.ftpQueue.length>0){
				StateLog.log(OrderState.FTP_LOAD,order.id,'','Старт загрузки'); 
				//loadProgress();
			}else{
				trace('FTPDownloadManager empty order '+order.ftp_folder);
				//checkDownload();
			}
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
			return o!=null && source && o.source==source.id && o.state>=OrderState.FTP_WAITE && o.state<=OrderState.FTP_CAPTURED;
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
			//cnn.removeEventListener(FTPEvent.SCAN_DIR,onList);
			//cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onListFault);
			cnn.removeEventListener(FTPEvent.DOWNLOAD,onDownload);
			cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onDownloadFault);
			cnn.removeEventListener(FTPEvent.DISCONNECTED,onDownloadDisconnected);
			//cnn.removeEventListener(FTPEvent.DISCONNECTED,onListDisconnected);

			//cnn.removeEventListener(ProgressEvent.PROGRESS, onProgress);
		}
		
		private function checkQueue():void{
			if(!isStarted || forceStop) return;

			switch(hasTask()){
				case -1:
					//ask for order
					trace('FTPDownloadManager checkQueue ask for order '+ftpService.url);
					if(connectionManager.canConnect()) dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FETCH_NEXT_EVENT));
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
					//has item to load
					if((order.state==OrderState.FTP_LOAD && order.ftpQueue) || (order.state<0 && !order.exceedErrLimit)){
						for each(ftpFile in order.ftpQueue){
							if(ftpFile){
								if(ftpFile.loadState==FTPFile.LOAD_WAIT) return 1;//cnn 4 load
								if(ftpFile.loadState==FTPFile.LOAD_ERR) return 1;//cnn 4 load //??? TODO add err counter & errLimit check
							}
						}
					}
					/*
					if(result!=0){
						if(order.state<0 && !order.exceedErrLimit) result=1;//cnn 4 list (reload)
					}
					*/
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
			var order:Order;
			var ftpFile:FTPFile;
			var downloadApplicant:FTPFile;
			for each(order in downloadOrders){
				if(order){
					//reset states
					if(order.state<0 && !order.exceedErrLimit) order.state=OrderState.FTP_LOAD;
					//scan
					if(order.state==OrderState.FTP_LOAD && order.ftpQueue){
						for each(ftpFile in order.ftpQueue){
							if(ftpFile){
								if(ftpFile.loadState==FTPFile.LOAD_WAIT){
									downloadApplicant=ftpFile;
									downloadApplicant.tag=order.id;
									break;
								}else if(!downloadApplicant && ftpFile.loadState==FTPFile.LOAD_ERR){
									downloadApplicant=ftpFile;
									downloadApplicant.tag=order.id;
								}
							}
						}
						if(downloadApplicant){
							if(downloadApplicant.loadState==FTPFile.LOAD_ERR){
								//TODO add err counter & errLimit check
								trace('ftp download err, restart');
								downloadApplicant.loadState=FTPFile.LOAD_WAIT;
							}
							break;
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
			//}else if(listCandidate && !listApplicant && listCandidate.ftp_folder){
			}else{
				//nothing to load, release connection
				if(DEBUG_TRACE) trace('FTPDownloadManager startTask release connection '+ftpService.url);
				connectionManager.release(cnn);
				//nothing to do ask 4 order 
				//dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FETCH_NEXT_EVENT));
			}
			return result;
		}

		private function onDownload(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			if(cnn){
				if(DEBUG_TRACE) trace('FTPDownloadManager file downloaded '+cnn.downloadFile.name);
				stopListen(cnn);
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FILE_LOADED_EVENT,null,'',cnn.downloadFile));
			}
			checkDownload();
			reuseConnection(cnn);
		}
		private function onDownloadFault(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			if(cnn){
				if(DEBUG_TRACE) trace('FTPDownloadManager download fault '+ cnn.downloadFile.fullPath);
				stopListen(cnn);
				StateLog.log(OrderState.ERR_LOAD,cnn.orderId,'','Ошибка загрузки "'+cnn.downloadFile.name+'": '+(e.error?e.error.message:''));
			}
			//reuseConnection(cnn);
			connectionManager.reconnect(cnn);
			//TODO err limit????
		}
		private function onDownloadDisconnected(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			stopListen(cnn);
			if(cnn){
				cnn.downloadFile.loadState=FTPFile.LOAD_ERR;
				if(DEBUG_TRACE) trace('FTPDownloadManager download Disconnected '+ cnn.downloadFile.fullPath);
				StateLog.log(OrderState.ERR_LOAD,cnn.orderId,'','Ошибка загрузки Disconnected '+cnn.downloadFile.name);
				connectionManager.reconnect(cnn);
			}
		}
		private function checkDownload():void{
			var order:Order;
			var complete:Array=[];
			var fault:Array=[];
			for each(order in downloadOrders){
				if(order){
					//completed
					if(order.state==OrderState.FTP_LOAD && order.isFtpQueueComplete){
						complete.push(order);
					}else if(order.state<0 && order.exceedErrLimit){
						fault.push(order);
					}
				}
			}
			if(DEBUG_TRACE && complete.length) trace('FTPDownloadManager checkDownload complete orders '+complete.length.toString());
			var idx:int;
			for each(order in complete){
				if(order){
					//remove from download
					idx=downloadOrders.indexOf(order);
					if(idx!=-1) downloadOrders.splice(idx,1);
					order.state=OrderState.FTP_WAITE_CHECK;
					order.resetErrCounter();
					//StateLog.log(order.state,order.id,'',''); 
					dispatchEvent(new ImageProviderEvent(ImageProviderEvent.ORDER_LOADED_EVENT,order));
				}
			}
			for each(order in fault){
				idx=downloadOrders.indexOf(order);
				if(idx!=-1) downloadOrders.splice(idx,1);
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.LOAD_FAULT_EVENT,order,order.errStateComment));
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