package com.photodispatcher.provider.ftp{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.AsyncSQLEvent;
	import com.photodispatcher.event.OrderLoadedEvent;
	import com.photodispatcher.factory.PrintGroupBuilder;
	import com.photodispatcher.factory.SuborderBuilder;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.PrintGroup;
	import com.photodispatcher.model.PrintGroupFile;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.Suborder;
	import com.photodispatcher.model.dao.OrderDAO;
	import com.photodispatcher.model.dao.OrderStateDAO;
	import com.photodispatcher.model.dao.StateLogDAO;
	import com.photodispatcher.provider.ImageProvider;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.util.ArrayUtil;
	import com.photodispatcher.util.StrUtil;
	
	import flash.data.SQLStatement;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.Dictionary;
	
	import mx.controls.Alert;
	
	import pl.maliboo.ftp.FTPFile;
	import pl.maliboo.ftp.events.FTPEvent;
	
	[Event(name="progress", type="flash.events.ProgressEvent")]
	[Event(name="orderLoaded", type="com.photodispatcher.event.OrderLoadedEvent")]
	public class FtpService extends ImageProvider{
		//TODO not in use, refactored to QueueManager
		
		[Bindable(event="connectionsLenthChange")]
		override public function get connectionsLenth():int{
			return connections.length;
		}

		[Bindable]
		public var lastError:String='';
			
		/*
		*open connections
		*/
		protected var connections:Array=[];
		
		public function FtpService(source:Source=null){
			super(source);
		}

		override public function start(resetErrors:Boolean=false):void{
			if(!source || !source.ftpService) return;
			//detect lockal folder
			var dstFolder:String=Context.getAttribute('workFolder');
			if(!dstFolder){
				//Alert.show('Не задана рабочая папка');
				lastError='Не задана рабочая папка';
				return;
			}
			var fl:File=new File(dstFolder);
			if(!fl.exists || !fl.isDirectory){
				//Alert.show('Не задана рабочая папка');
				lastError='Не задана рабочая папка';
				return;
			}
			//check create source folder
			fl=fl.resolvePath(StrUtil.toFileName(source.name));
			try{
				if(!fl.exists) fl.createDirectory();
			}catch(e:Error){
				//Alert.show('Ошибка доступа. Папка: '+fl.nativePath);
				lastError='Ошибка доступа. Папка: '+fl.nativePath;
				return;
			}
			localFolder=fl.nativePath;
			if(resetErrors){
			//reset err limit
				var order:Order;
				for each(order in queue){
					if(order){
						order.resetErrCounter();
						if(order.state<0 && order.state!=OrderState.ERR_WRITE_LOCK) order.state=order.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
					}
				}
			}
			trace('FtpService starting for '+source.ftpService.url);
			lastError='';
			startMeter();
			_isStarted=true;
			forceStop=false;
			dispatchEvent(new Event('isStartedChange'));
			checkQueue();
		}
		override public function stop():void{
			_isStarted=false;
			forceStop=true;
			webOrderId='';
			listOrderId='';
			//flushWriteQueue();

			var order:Order;

			//stop download
			for each(order in downloadOrders){
				if(order){
					stopDownload(order.id);
					order.ftpQueue=[];
					order.printGroups=[];
					order.suborders=[]
					if(order.ftpForwarded){
						order.state=OrderState.FTP_FORWARD;
					}else{
						order.state=OrderState.WAITE_FTP;
					}
					queue.unshift(order);
				}
			}
			downloadOrders=[];

			//reset runtime states
			for each(order in queue){
				if(order){
					if(order.state==OrderState.FTP_WEB_CHECK || order.state==OrderState.FTP_WEB_OK || order.state==OrderState.FTP_LIST){
						order.state=order.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
					}
					//reset errors
					if(order.state<0 && order.state!=OrderState.ERR_WRITE_LOCK){
						if(!order.exceedErrLimit) {
							order.state=order.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
						}
					}
				}
			}

			dispatchEvent(new Event('queueLenthChange'));
			dispatchEvent(new Event('processingLenthChange'));
			loadProgress();

			trace('FtpService stop '+source.ftpService.url);
			//stop connections if any (list connection ...) 
			while(connections.length>0){
				var cnn:FtpTask=connections[0] as FtpTask;
				closeConnection(cnn);
			}
			stopMeter();
			dispatchEvent(new Event('isStartedChange'));
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
		override public function reSync(orders:Array):void{
			trace('FtpService reSync '+source.ftpService.url);
			//flushWriteQueue();
			//empty responce from DAO?
			if(!orders) return;
			var syncOrders:Array=orders.filter(reSyncFilter);
			var order:Order;
			
			if(syncOrders.length==0){
				//nothig to process
				//clear queue
				queue=[];
				//stop downloadOrders
				if(downloadOrders && downloadOrders.length>0){
					for each(order in downloadOrders){
						if(order) stopDownload(order.id);
					}
				}
				downloadOrders=[];
				dispatchEvent(new Event('queueLenthChange'));
				dispatchEvent(new Event('processingLenthChange'));
				return;
			}
			
			//keep current, remove if not in sync, add new
			var syncMap:Object= arrayToMap(syncOrders);
			var toKill:Array=[];
			var toReplace:Array=[];
			var idx:int;
			
			//check downloadOrders
			for each (order in downloadOrders){
				if(order){
					if (syncMap[order.id]){
						//replace in input arr
						toReplace.push(order);
						//remove from map
						delete syncMap[order.id];
					}else{
						toKill.push(order);
						//stop
						stopDownload(order.id);
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

			//check queue
			toKill=[];
			for each (order in queue){
				if(order){
					if (syncMap[order.id]){
						//replace
						toReplace.push(order);
						//remove from map
						delete syncMap[order.id];
					}else{
						toKill.push(order);
					}
				}
			}
			//remove
			for each (order in toKill){
				if(order){
					idx=ArrayUtil.searchItemIdx('id',order.id,queue);
					if(idx!=-1) queue.splice(idx,1);
				}
			}
			
			//replace
			for each (order in toReplace){
				if(order){
					idx=ArrayUtil.searchItemIdx('id',order.id,orders);
					if(idx!=-1) orders[idx]=order;
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
			dispatchEvent(new Event('processingLenthChange'));
			//if(isStarted) checkQueue();
			if(isStarted) restoreConnections();
		}
		
		protected function reSyncFilter(element:*, index:int, arr:Array):Boolean {
			var o:Order=element as Order;
			//return o!=null && o.state==syncState;
			return o!=null && source && o.source==source.id && (o.state==OrderState.WAITE_FTP || o.state<0);
		}

		private var webOrderId:String;
		private function checkQueue():void{
			if(webOrderId || !isStarted || forceStop) return;
			if(connections.length >= source.ftpService.connections) return;
			
			//recheck download orders
			checkDownloadOrders();
			
			var newOrder:Order;
			var ord:Order;
			var o:Object;
			//chek queue
			for each (o in queue){
				ord= o as Order;
				if(ord && !ord.exceedErrLimit){
					if(ord.state>0){
						if(!webOrderId && ord.state==OrderState.FTP_WEB_CHECK) ord.state=ord.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
						//if(!listOrderId && ord.state==OrderState.FTP_LIST) ord.state=ord.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
						if(ord.state==OrderState.FTP_WEB_OK && ord.id!=listOrderId) ord.state=ord.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
						if(ord.state==OrderState.WAITE_FTP || ord.state==OrderState.FTP_FORWARD){
							if(!newOrder){
								newOrder=ord;
							}else if(!newOrder.ftpForwarded && ord.ftpForwarded){
								newOrder=ord;
							}
						}
					}else if(ord.state!=OrderState.ERR_WRITE_LOCK){
						//if(!ord.exceedErrLimit){
							//reset error
							ord.state=ord.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
						//}
					}
				}
			}
			
			if(newOrder){
				trace('FtpService.checkQueue web request '+newOrder.ftp_folder);
				//check state on site
				webOrderId=newOrder.id;
				newOrder.state=OrderState.FTP_WEB_CHECK;
				//var w:ProfotoWeb= new ProfotoWeb(source);
				var w:BaseWeb= WebServiceBuilder.build(source);
				w.addEventListener(Event.COMPLETE,getOrderHandle);
				w.getOrder(newOrder);
			}
		}
		
		private var listOrderId:String;
		private function getOrderHandle(e:Event):void{
			var pw:BaseWeb=e.target as BaseWeb;
			pw.removeEventListener(Event.COMPLETE,getOrderHandle);
			if(!webOrderId) return;
			var startOrder:Order=getOrderById(webOrderId);
			webOrderId='';
			if(!startOrder || startOrder.state!=OrderState.FTP_WEB_CHECK){
				return;
			}
			if(listOrderId || connections.length >= source.ftpService.connections){
				startOrder.state=startOrder.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
				return;
			}
			
			if(pw.hasError){
				trace('getOrderHandle web check order err: '+pw.errMesage);
				startOrder.state=OrderState.ERR_WEB;
				StateLogDAO.logState(OrderState.ERR_WEB,startOrder.id,'','Ошибка проверки на сайте: '+pw.errMesage); 
				checkQueue();
				return;
			}
			if(pw.isValidLastOrder(true)){
				//open cnn & get files list
				trace('FtpService.getOrderHandle; web check Ok; openConnection for '+startOrder.ftp_folder);
				listOrderId=startOrder.id;
				//startOrder.state=startOrder.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
				startOrder.state=OrderState.FTP_WEB_OK;
				openConnection();
				return;
			}else{
				//mark as canceled
				trace('FtpService.getOrderHandle; web check fault; order canceled '+startOrder.ftp_folder);
				startOrder.state=OrderState.CANCELED;
				checkQueue();
				return;
			}
		}

		private function restoreConnections():void{
			if(connections.length >= source.ftpService.connections){
				return;
			}
			//need download connections
			var order:Order;
			var ftpFile:FTPFile;
			var need:int=0;
			for each(order in downloadOrders){
				if(order && order.state==OrderState.FTP_LOAD && order.ftpQueue){
					for each(ftpFile in order.ftpQueue){
						if(ftpFile && ftpFile.loadState==FTPFile.LOAD_WAIT){
							need++;
							break;
						}
					}
				}
			}
			var toOpen:int=Math.min(need, source.ftpService.connections-connections.length);
			var i:int;
			for(i=0; i<toOpen;i++){
				openConnection();
			}
			if(source.ftpService.connections>connections.length) checkQueue();
		}
		
		private function openConnection():void{
			if(connections.length >= source.ftpService.connections){
				listOrderId='';
				return;
			}
			var cnn:FtpTask=new FtpTask(source);
			cnn.addEventListener(FTPEvent.LOGGED,onLogged);
			cnn.addEventListener(FTPEvent.INVOKE_ERROR,onLoggFault);
			connections.push(cnn);
			trace('FtpService start new connection, connections:'+connections.length.toString());
			dispatchEvent(new Event('connectionsLenthChange'));
			cnn.connect();
		}
		private function closeConnection(cnn:FtpTask):void{
			if(connections.length>0){
				var i:int=connections.indexOf(cnn);
				if(i!=-1) connections.splice(i,1);
			}
			cnn.removeEventListener(FTPEvent.LOGGED,onLogged);
			cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onLoggFault);
			cnn.removeEventListener(FTPEvent.SCAN_DIR,onList);
			cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onListFault);
			cnn.removeEventListener(FTPEvent.DOWNLOAD,onDownload);
			cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onDownloadFault);
			cnn.removeEventListener(ProgressEvent.PROGRESS, onProgress);

			trace('FtpService close connection, connections:'+connections.length.toString());
			dispatchEvent(new Event('connectionsLenthChange'));
			cnn.close();
		}
		
		private function onLogged(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			if(!cnn) return;
			trace('FtpService log complited '+source.ftpService.url);
			lastError='';
			cnn.removeEventListener(FTPEvent.LOGGED,onLogged);
			cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onLoggFault);
			var ftpFile:FTPFile=getNextDownload();
			if(ftpFile){
				//start download
				startDownload(cnn,ftpFile);
			}else{
				if(listOrderId){
					listFolder(cnn);
				}else{
					closeConnection(cnn);
					checkQueue();
				}
			}
		}
		
		private function listFolder(cnn:FtpTask):void{
			if(!listOrderId){
				closeConnection(cnn);
				return;
			}
			var o:Order=getOrderById(listOrderId);
			listOrderId='';
			if(o && o.state==OrderState.FTP_WEB_OK){
				cnn.orderId=o.id;
				cnn.addEventListener(FTPEvent.SCAN_DIR,onList);
				cnn.addEventListener(FTPEvent.INVOKE_ERROR,onListFault);
				o.state=OrderState.FTP_LIST;
				cnn.scanFolder(o.ftp_folder);
			}else{
				closeConnection(cnn);
			}
		}
		
		private function onLoggFault(e:FTPEvent):void{
			//TODO ftp connect error, stop manager?
			trace('FtpService login fault '+source.ftpService.url);
			//Alert.show('Ошибка подключения ftp: '+source.ftpService.url+'; '+(e.error?e.error.message:''));
			lastError='Ошибка подключения ftp: '+source.ftpService.url;
			var cnn:FtpTask=e.target as FtpTask;
			if(cnn){
				closeConnection(cnn);
			}
			listOrderId='';
		}
		
		private function onList(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			if(!cnn) return;
			var orderId:String=cnn.orderId;
			cnn.removeEventListener(FTPEvent.SCAN_DIR,onList);
			cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onListFault);
			if(!orderId) return;
			trace('FtpService scan folder complited '+orderId);
			var o:Order=getOrderById(orderId);
			if(!o || o.state!=OrderState.FTP_LIST){
				//reuse connection
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
				trace('FtpService empty ftp folder '+orderId);
				o.state=OrderState.ERR_FTP;
				o.setErrLimit();
				StateLogDAO.logState(OrderState.ERR_FTP,o.id,'','Пустой список файлов. Папка заказа не найдена или пуста'); 
				//reuse connection
				reuseConnection(cnn);
				return;
			}
			//buid suborders
			var soArr:Array;
			try{
				soArr= SuborderBuilder.build(source,fileStructure,orderId);
			}catch (e:Error){
				trace('FtpService error while build suborders '+orderId);
				o.state=OrderState.ERR_READ_LOCK;
				StateLogDAO.logState(OrderState.ERR_READ_LOCK,o.id,'','Блокировка чтения при парсе подзаказов.'); 
				//reuse connection
				reuseConnection(cnn);
				return;
			}
			
			var pgBuilder:PrintGroupBuilder= new PrintGroupBuilder();
			var pgArr:Array;
			//build print groups 
			try{
				pgArr= pgBuilder.build(source,fileStructure,orderId);
			}catch (e:Error){
				trace('FtpService error while build print group'+orderId);
				o.state=OrderState.ERR_READ_LOCK;
				StateLogDAO.logState(OrderState.ERR_READ_LOCK,o.id,'','Блокировка чтения при парсе групп печати.'); 
				//reuse connection
				reuseConnection(cnn);
				return;
			}

			//check/create order local folder
			var fl:File=new File(localFolder);
			fl=fl.resolvePath(o.ftp_folder);
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
				//Alert.show('Ошибка доступа. Папка: '+fl.nativePath);
				o.state=OrderState.ERR_FILE_SYSTEM;
				StateLogDAO.logState(OrderState.ERR_FILE_SYSTEM,o.id,'','Папка: '+fl.nativePath+': '+err.message); 
				reuseConnection(cnn);
				return;
			}

			//remove from queue put to download
			o=getOrderById(orderId,true); 
			if(o){
				o.local_folder=fl.parent.nativePath;
				o.printGroups=pgArr;
				o.suborders=soArr;
				o.state=OrderState.FTP_LOAD;
				o.ftpQueue=e.listing;
				trace('FtpService start download order '+o.ftp_folder+', printGroups:'+o.printGroups.length.toString()+', ftpQueue:'+o.ftpQueue.length.toString());
				if(o.ftpQueue && o.ftpQueue.length>0){
					StateLogDAO.logState(OrderState.FTP_LOAD,o.id,'','Старт загрузки'); 
					downloadOrders.push(o);
					//open extra connections
					var toOpen:int=Math.min(o.ftpQueue.length-1, source.ftpService.connections-connections.length);
					var i:int;
					for(i=0; i<toOpen;i++){
						openConnection();
					}
					if(source.ftpService.connections>connections.length) checkQueue();
				}else{
					trace('FtpService empty order '+o.ftp_folder+', printGroups:'+o.printGroups.length.toString()+', ftpQueue:'+o.ftpQueue.length.toString());
					dispatchEvent(new OrderLoadedEvent(o));
				}
				loadProgress();
				dispatchEvent(new Event('processingLenthChange'));
			}
			reuseConnection(cnn);
		}
		private function onListFault(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			if(!cnn) return;
			trace('FtpService scan folder fault '+cnn.orderId);
			cnn.removeEventListener(FTPEvent.SCAN_DIR,onList);
			cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onListFault);
			var o:Order=getOrderById(cnn.orderId);
			if(o){
				o.state=OrderState.ERR_FTP;
				StateLogDAO.logState(OrderState.ERR_FTP,o.id,'','Ошибка FTP LIST "'+o.ftp_folder+'": ' + e.error?e.error.message:''); 
			}
			//reopen connection
			closeConnection(cnn);
			openConnection();
			//reuseConnection(cnn);
		}
		
		private function getNextDownload():FTPFile{
			if(!downloadOrders || downloadOrders.length==0) return null;
			var order:Order;
			var ftpFile:FTPFile;
			var fF:FTPFile;
			var o:Object;
			for each(o in downloadOrders){
				order=o as Order;
				if(order && order.state==OrderState.FTP_LOAD && order.ftpQueue){
					for each(o in order.ftpQueue){
						fF=o as FTPFile;
						if(fF && fF.loadState==FTPFile.LOAD_WAIT){
							ftpFile=fF;
							break;
						}
					}
				}
				if(ftpFile){
					ftpFile.tag=order.id;
					break;
				}
			}
			return ftpFile;
		}
		
		private function reuseConnection(cnn:FtpTask):void{
			if(!cnn) return;
			var ftpFile:FTPFile=getNextDownload();
			if(ftpFile){
				//start download
				startDownload(cnn,ftpFile);
				//try to open new connection
				openConnection();
			}else{
				if(listOrderId){
					listFolder(cnn);
				}else{
					closeConnection(cnn);
					checkQueue();
				}
			}
		}
		
		private function startDownload(cnn:FtpTask,ftpFile:FTPFile):void{
			cnn.orderId=ftpFile.tag;
			cnn.addEventListener(FTPEvent.DOWNLOAD,onDownload);
			cnn.addEventListener(FTPEvent.INVOKE_ERROR,onDownloadFault);
			cnn.addEventListener(ProgressEvent.PROGRESS, onProgress);
			cnn.download(ftpFile,localFolder);
		}
		
		/**
		 * 
		 *force stop all running order connections, exclude keepConnection
		 * @param orderId
		 * @param keepConnection
		 * 
		 */		
		private function stopDownload(orderId:String, keepConnection:FtpTask=null):void{
			var c:FtpTask; var a:Array=[];
			for each (c in connections){
				if(c && c.orderId==orderId){
					if(!keepConnection || c!==keepConnection) a.push(c);
				}
			}
			for each (c in a){
				closeConnection(c);
			}
		}

		private function checkDownloadOrders():void{
			var order:Order;
			var restart:Array=[];
			var complete:Array=[];
			for each(order in downloadOrders){
				if(order){
					if(order.state != OrderState.FTP_LOAD){//???
						stopDownload(order.id);
						restart.push(order);
						StateLogDAO.logState(order.state,order.id,'','Статус заказа "'+order.state_name+'" FTP загрузка отменена (FtpService.checkDownloadOrders)'); 
					}else  if(order.ftpQueueHasErr){
						stopDownload(order.id);
						if(order.state!=OrderState.ERR_FTP) order.state=OrderState.ERR_FTP;
						restart.push(order);
						StateLogDAO.logState(OrderState.ERR_FTP,order.id,'','Ошибка загрузки (FtpService.checkDownloadOrders)'); 
					}else  if(order.isFtpQueueComplete){
						//completed
						complete.push(order);
						StateLogDAO.logState(order.state,order.id,'','FTP загрузка завершена (FtpService.checkDownloadOrders)'); 
						dispatchEvent(new OrderLoadedEvent(order));
					}
				}
			}

			var idx:int;
			//restart
			for each(order in restart){
				if(order){
					idx=downloadOrders.indexOf(order);
					if(idx!=-1){
						//remove from download
						downloadOrders.splice(idx,1);
					}
					//return to queue
					order.printGroups=[];
					order.suborders=[];
					order.ftpQueue=[];
					queue.push(order);
				}
			}
			//remove completed
			for each(order in complete){
				if(order){
					idx=downloadOrders.indexOf(order);
					if(idx!=-1){
						//remove from download
						downloadOrders.splice(idx,1);
					}
				}
			}

			dispatchEvent(new Event('queueLenthChange'));
			dispatchEvent(new Event('processingLenthChange'));
			loadProgress();
		}

		private function onDownload(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			if(!cnn) return;
			cnn.removeEventListener(FTPEvent.DOWNLOAD,onDownload);
			cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onDownloadFault);
			cnn.removeEventListener(ProgressEvent.PROGRESS, onProgress);
			//check order complite
			var idx:int=ArrayUtil.searchItemIdx('id',cnn.orderId,downloadOrders);
			var order:Order;
			if(idx!=-1){
				order=downloadOrders[idx] as Order;
				if(order){
					if(order.state != OrderState.FTP_LOAD){
						trace('FtpService order canceled '+ order.ftp_folder);
						//remove from download
						downloadOrders.splice(idx,1);
						stopDownload(order.id,cnn);
						//return to queue 
						order.printGroups=[];
						order.suborders=[];
						order.ftpQueue=[];
						queue.push(order);
						StateLogDAO.logState(order.state,order.id,'','Статус заказа "'+order.state_name+'" FTP загрузка отменена.'); 
					}else  if(order.ftpQueueHasErr){
						//double error check, miss err event?
						downloadOrders.splice(idx,1);
						stopDownload(order.id);
						if(order.state!=OrderState.ERR_FTP) order.state=OrderState.ERR_FTP;
						order.printGroups=[];
						order.suborders=[];
						order.ftpQueue=[];
						queue.push(order);
						StateLogDAO.logState(OrderState.ERR_FTP,cnn.orderId,'','Ошибка загрузки (FtpService.onDownload) '+cnn.downloadFile.name); 
					}else  if(order.isFtpQueueComplete){
						//completed
						StateLogDAO.logState(order.state,order.id,'','FTP загрузка завершена'); 
						trace('FtpService ftp download complete order: '+ order.ftp_folder);
						downloadOrders.splice(idx,1);
						dispatchEvent(new OrderLoadedEvent(order));
					}
				}
			}
			if(idx==-1 || ! order){
				StateLogDAO.logState(OrderState.ERR_FTP,cnn.orderId,'','FtpService.onDownload. Заказ не найден в очереди загрузки.'); 
			}
			dispatchEvent(new Event('queueLenthChange'));
			dispatchEvent(new Event('processingLenthChange'));
			loadProgress();
			reuseConnection(cnn);
		}
		private function onDownloadFault(e:FTPEvent):void{
			var cnn:FtpTask=e.target as FtpTask;
			if(!cnn) return;
			trace('FtpService download fault '+ cnn.downloadFile.fullPath);
			cnn.removeEventListener(FTPEvent.DOWNLOAD,onDownload);
			cnn.removeEventListener(FTPEvent.INVOKE_ERROR,onDownloadFault);
			cnn.removeEventListener(ProgressEvent.PROGRESS, onProgress);
			
			stopDownload(cnn.orderId);
			StateLogDAO.logState(OrderState.ERR_FTP,cnn.orderId,'','Ошибка загрузки "'+cnn.downloadFile.name+'": '+(e.error?e.error.message:'')); 

			var idx:int=ArrayUtil.searchItemIdx('id',cnn.orderId,downloadOrders);
			var o:Order;
			if(idx!=-1){
				o=downloadOrders.splice(idx,1)[0] as Order;
				if(o){
					if(o.state!=OrderState.ERR_FTP) o.state=OrderState.ERR_FTP;
					o.printGroups=[];
					o.suborders=[];
					o.ftpQueue=[];
					queue.push(o);
				}
			}
			if(idx==-1 || !o){
				StateLogDAO.logState(OrderState.ERR_FTP,cnn.orderId,'','FtpService.onDownloadFault. Заказ не найден в очереди загрузки.'); 
			}

			dispatchEvent(new Event('queueLenthChange'));
			dispatchEvent(new Event('processingLenthChange'));
			
			loadProgress();
			//reopen connection
			//closeConnection(cnn);
			openConnection();
		}
		
		//parse suborders
		private function parseSubordes(order:Order):Boolean{
			//TODO closed while not implemented, has unprocessed errors
			return true;
			
			if (!order || !order.hasSuborders) return true;
			var rootFolder:File=new File(localFolder);
			rootFolder=rootFolder.resolvePath(order.ftp_folder);
			if(!rootFolder.exists){
				order.state=OrderState.ERR_FILE_SYSTEM;
				StateLogDAO.logState(OrderState.ERR_FILE_SYSTEM,order.id,'','Папка заказа не найдена: '+rootFolder.nativePath); 
				return false;
			}
			var so:Suborder;
			var soFolder:File;
			var relFile:File;
			for each(so in order.suborders){
				if(so){
					soFolder=rootFolder.resolvePath(so.ftp_folder);
					if(!soFolder.exists){
						order.state=OrderState.ERR_FILE_SYSTEM;
						StateLogDAO.logState(OrderState.ERR_FILE_SYSTEM,order.id,'','Папка подзаказа не найдена: '+soFolder.nativePath); 
						return false;
					}
					relFile=soFolder.resolvePath('relations.txt');
					if(!relFile.exists){
						order.state=OrderState.ERR_FILE_SYSTEM;
						StateLogDAO.logState(OrderState.ERR_FILE_SYSTEM,order.id,'','Файл подзаказа не найдена: '+relFile.nativePath); 
						return false;
					}
					//read relations.txt
					var txt:String;
					try{
						var fs:FileStream=new FileStream();
						fs.open(relFile,FileMode.READ);
						txt=fs.readUTFBytes(fs.bytesAvailable);
						fs.close();
					} catch(err:Error){
						order.state=OrderState.ERR_FILE_SYSTEM;
						StateLogDAO.logState(OrderState.ERR_FILE_SYSTEM,order.id,'','Ошибка чтения файла: '+relFile.nativePath); 
						return false;
					}
					txt=txt.replace(File.lineEnding, '\n');
					var lines:Array=txt.split('\n');
					var newSo:Suborder;
					var poz:int;
					if(lines && lines.length>0){
						//parse
						//0000 - Календарь 12 мес._20 × 30_6899.jpg 
						for each (txt in lines){
							if(txt){
								poz=txt.lastIndexOf('_');
								if(poz!=-1){
									txt=txt.substr(poz+1);
									poz=txt.lastIndexOf('.');
									if(poz!=-1){
										txt=txt.substring(0,poz);
										var subId:int=int(txt);
										if(subId){
											newSo=so.clone();
											newSo.sub_id=subId;
											newSo.fillId();
											newSo.fillFolder();
											order.addSuborder(newSo);
										}
									}
								}
							}
						}
					}
					//TODO refactor - can't remove in for each
					order.removeSuborder(so);
				}
			}
			return true;
		}
		
		private function onProgress(e:ProgressEvent):void{
			meter[meterIndex]+=e.bytesLoaded;
		}
		
		private function loadProgress():void{
			var total:int=0;
			var done:int=0;
			_loadProgressOrders='';
			if(downloadOrders && downloadOrders.length>0){
				var order:Order;
				for each(var o:Object in downloadOrders){
					order=o as Order;
					if(_loadProgressOrders) _loadProgressOrders+=', ';
					_loadProgressOrders+=order.ftp_folder;
					//total files
					total=total+order.ftpQueue.length;
					//done
					var ff:FTPFile;
					for each(o in order.ftpQueue){
						ff= o as FTPFile;
						if (ff.loadState==FTPFile.LOAD_COMPLETE) done++;
					}
				}
			}
			dispatchEvent(new Event('loadProgressOrdersChange'));
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,done,total));
		}
		
	}
}