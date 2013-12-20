package com.photodispatcher.provider.fbook.download{
	import com.akmeful.fotokniga.net.AuthService;
	import com.akmeful.json.JsonUtil;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.model.Suborder;
	import com.photodispatcher.model.dao.StateLogDAO;
	import com.photodispatcher.provider.fbook.FBookProject;
	import com.photodispatcher.provider.fbook.TripleState;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import mx.rpc.AsyncResponder;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	
	[Event(name="orderLoaded", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="flowError", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="loadFault", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="progress", type="flash.events.ProgressEvent")]
	public class FBookDownloadManager extends EventDispatcher{
		//TODO implement cache mode ?
		public static const CACHE_CLIPART:Boolean=false;

		protected var source:Source;
		//protected var ftpService:SourceService;
		protected var _isStarted:Boolean=false;
		protected var localFolder:String;
		protected var forceStop:Boolean=false;
		//protected var connectionManager:FTPConnectionManager;
		//protected var downloadOrders:Array=[];
		//private var listApplicant:Order;
		private var remoteMode:Boolean;
		
		/*
		*orders Queue
		*/
		private var queue:Array=[];
		[Bindable]
		public var currentOrder:Order;
		private var currentSubOrder:Suborder;

		private var projectLoader:FBookProjectLoader;
		private var _speed:Number=0;
		
		[Bindable(event="queueLenthChange")]
		public function get queueLenth():int{
			return queue.length;
		}

		public function FBookDownloadManager(source:Source,remoteMode:Boolean=false){
			super(null);
			this.source=source;
			this.remoteMode=remoteMode;

		}
		
		public function get isStarted():Boolean{
			return _isStarted;
		}

		public function start():Boolean{
			//TODO reset state
			forceStop=false;
			
			//check
			if(!source || !source.hasFbookService){
				flowError('Ошибка инициализации');
				return false;
			}
			localFolder=source.getWrkFolder();
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
			if(source.type_id == SourceType.SRC_PROFOTO){
				//use main login, no auth needed
				_isStarted=true;
				checkQueue();
			}else{
				//check login
				var auth:AuthService;
				if(!AuthService.instance){ 
					auth= new AuthService();
					auth.method='POST';
					auth.resultFormat='text';
				}
				if(!AuthService.instance.authorized){
					//attempt to login
					auth.baseUrl=source.fbookService.url;
					var token:AsyncToken;
					token=auth.siteLogin(source.fbookService.user,source.fbookService.pass);
					token.addResponder(new AsyncResponder(login_ResultHandler,login_FaultHandler));
				}else{
					_isStarted=true;
					checkQueue();
				}
			}
			return true;
		}
		
		/**
		 * 
		 * @return array stoped orders  
		 * 
		 */		
		public function stop():Array{
			if(source.fbookService) trace('FBookDownloadManager stop '+source.fbookService.url);
			var result:Array=[];
			forceStop=true;
			_isStarted=false;
			//stop downloadOrders
			var order:Order;
			if(queue && queue.length>0){
				result=queue.concat();
				for each(order in result){
					if(order) stopDownload(order);
				}
			}
			trace('FBookDownloadManager stoped '+result.length.toString()+' orders');
			queue=[];
			currentOrder=null;
			currentSubOrder=null;
			dispatchEvent(new Event('queueLenthChange'));
			return result;
		}
		
		public function destroy():void{
			if(isStarted) stop();
			if(projectLoader){
				projectLoader.removeEventListener(Event.COMPLETE, onProjectLoaded);
				projectLoader=null;
			}
		}

		public function reSync(orders:Array):void{
			trace('FBookDownloadManager reSync '+source.fbookService.url);
			//empty responce from DAO?
			if(!orders) return;
			var syncOrders:Array=orders.filter(reSyncFilter);
			var order:Order;
			var arr:Array;
			if(syncOrders.length==0){
				//nothig to process
				//stop downloadOrders
				if(queue && queue.length>0){
					arr=queue.concat();
					for each(order in arr){
						if(order) stopDownload(order);
					}
				}
				queue=[];
				currentOrder=null;
				currentSubOrder=null;
				dispatchEvent(new Event('queueLenthChange'));
				return;
			}
			
			//keep current, remove if not in sync
			var toReplace:Array=[];
			var idx:int;
			arr=queue.concat();
			//check queue
			for each (order in arr){
				if(order){
					idx=ArrayUtil.searchItemIdx('id',order.id,syncOrders);
					if (idx!=-1){
						//replace in input arr
						toReplace.push(order);
					}else{
						//stop
						stopDownload(order);
					}
				}
			}
			//replace
			for each (order in toReplace){
				if(order){
					idx=ArrayUtil.searchItemIdx('id',order.id,orders);
					if(idx!=-1) orders[idx]=order;
				}
			}
			
			dispatchEvent(new Event('queueLenthChange'));
			checkQueue();
		}
		protected function reSyncFilter(element:*, index:int, arr:Array):Boolean {
			var o:Order=element as Order;
			//return o!=null && o.state==syncState;
			return o!=null && source && o.source==source.id && o.state==OrderState.WAITE_FTP;
		}

		
		private function stopDownload(order:Order):void {
			if(!order) return;
			trace('FBookDownloadManager stopDownload '+order.id);
			if(order===currentOrder){
				currentOrder=null;
				currentSubOrder=null;
				if(contentLoader){
					contentLoader.stop();
					contentLoader=null;
				}
			}
			removeFromQueue(order);
		}
		
		private function login_ResultHandler(event:ResultEvent, token:AsyncToken):void {
			var r:Object = JsonUtil.decode(event.result as String);
			if(r.result){
				//start service
				_isStarted=true;
				//dispatchEvent(new Event('isStartedChange'));
				checkQueue();
			} else {
				_isStarted=false;
				flowError('Ошибка подключения к '+source.fbookService.url);
			}
			//token=null;
		}
		private function login_FaultHandler(event:FaultEvent, token:AsyncToken):void {
			_isStarted = false;
			flowError('Ошибка подключения к '+source.fbookService.url+': '+event.fault.faultString);
			//token=null;
		}
		
		public function download(order:Order):void{
			var so:Suborder;
			if(order){
				if(order.suborders && order.suborders.length>0){
					trace('FBookDownloadManager added order '+order.id);
					order.state=OrderState.FTP_WAITE_SUBORDER;
					for each(so in order.suborders){
						if(so) so.state=OrderState.FTP_WAITE_SUBORDER;
					}
					queue.push(order);
					dispatchEvent(new Event('queueLenthChange'));
					checkQueue();
				}else{
					order.state=OrderState.FTP_COMPLETE;
					order.resetErrCounter();
					//if(!remoteMode) StateLogDAO.logState(order.state,order.id); 
					dispatchEvent(new ImageProviderEvent(ImageProviderEvent.ORDER_LOADED_EVENT,order));
				}
			}
		}

		private function checkQueue():void{
			if(!isStarted || forceStop) return;//stoped
			if(currentOrder) return; //is busy
			if(!queue || queue.length==0) return; //nothing to load
			var order:Order;
			var newOrder:Order;
			var restartOrder:Order;
			var compliteWithErr:Array=[];
			
			for each (order in queue){  
				if(order){
					if(order.state<0){
						//check/reset error state
						if(order.exceedErrLimit){
							//stop to load order ?????
							compliteWithErr.push(order);
						}else{
							//reset & start at next iteration
							order.state=OrderState.FTP_WAITE_SUBORDER;
							restartOrder=order;
						}
					}else if(order.state==OrderState.FTP_WAITE_SUBORDER){
						if(!newOrder){
							newOrder=order;
							if(newOrder.ftpForwarded) break;
						}else if(!newOrder.ftpForwarded && order.ftpForwarded){
							newOrder=order;
							break;
						}
					}
				}
			}
			//process err orders!!! neve exec 
			for each (order in compliteWithErr){
				removeFromQueue(order);
				if(order) dispatchEvent(new ImageProviderEvent(ImageProviderEvent.LOAD_FAULT_EVENT,order,'exceedErrLimit Flow bug'));
			}
			//start to load
			if(!newOrder) newOrder=restartOrder;//start reseted at this iteration
			if(newOrder){
				currentOrder=newOrder;
				currentOrder.state=OrderState.FTP_LOAD;
				if(!remoteMode) StateLogDAO.logState(currentOrder.state,currentOrder.id,null,'Загрузка подзаказов');
				nextSubOrder();
			}else{
				checkQueue();
			}
		}
		
		private function nextSubOrder():void{
			var so:Suborder;
			var vsErr:Suborder;
			var toLoad:Suborder;
			if(!currentOrder){
				checkQueue();
				return;
			}
			//get next not loaded
			for each(so in currentOrder.suborders){
				if (so){
					if(so.state<0) so.state=OrderState.FTP_WAITE_SUBORDER;//reset
					if(so.state==OrderState.FTP_WAITE_SUBORDER){
						toLoad=so;
						break;
					}
				}
			}
			if(!toLoad){
				//currentOrder completed
				currentOrder.state=OrderState.FTP_COMPLETE;
				currentOrder.resetErrCounter();
				removeFromQueue(currentOrder);
				if(!remoteMode) StateLogDAO.logState(currentOrder.state,currentOrder.id,null,'Завершена загрузка подзаказов'); 
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.ORDER_LOADED_EVENT,currentOrder));
				currentOrder=null;
				currentSubOrder=null;
				dispatchEvent(new Event('queueLenthChange'));
				checkQueue();
				return;
			}
			currentSubOrder=toLoad;
			//load project
			currentSubOrder.state=OrderState.FTP_GET_PROJECT;
			if(!projectLoader){
				projectLoader= new FBookProjectLoader(source);
				projectLoader.addEventListener(Event.COMPLETE, onProjectLoaded);
			}
			projectLoader.fetchProject(currentSubOrder.sub_id);
		}
		
		private function onProjectLoaded(event:Event):void{
			//var order:Order;
			if(!currentSubOrder || !currentOrder) return;
			var project:FBookProject=projectLoader.lastFetchedProject;
			var workFolder:File;
			if(project){
				//currentSubOrder.ftp_folder=currentOrder.ftp_folder+File.separator+'fb'+project.id.toString();
				//chek create suborder folder
				var file:File=new File(localFolder);
				file=file.resolvePath(currentOrder.ftp_folder+File.separator+currentSubOrder.ftp_folder);
				try{
					if(file.exists){
						if(file.isDirectory){
							file.deleteDirectory(true);
						}else{
							file.deleteFile();
						}
					}
					file.createDirectory();
					//create wrk subfolder
					file=file.resolvePath(FBookProject.SUBDIR_WRK);
					file.createDirectory();
					workFolder=file;
					//create subdirs
					var subDir:String;
					for each (subDir in FBookProject.getWorkSubDirs()){
						if (subDir){
							file=workFolder.resolvePath(subDir);
							file.createDirectory();
						}
					}
				}catch(err:Error){
					currentSubOrder.state=OrderState.ERR_FILE_SYSTEM;
					currentOrder.state=OrderState.ERR_FILE_SYSTEM;
					if(!remoteMode) StateLogDAO.logState(currentOrder.state,currentOrder.id,null,'Папка: '+file.nativePath+' '+err.message); 
					if(currentOrder.exceedErrLimit) releaseWithError(currentOrder,err.message);
					currentOrder=null;
					currentSubOrder=null;
					checkQueue();
					return;
				}
				currentSubOrder.project=project;
				
				//fill extra info
				currentSubOrder.calc_type='Розница';
				currentSubOrder.endpaper=project.endpaperName;
				currentSubOrder.interlayer=project.interlayerName;
				currentSubOrder.cover=project.coverName;
				currentSubOrder.format=project.formatName;
				currentSubOrder.corner_type=project.cornerTypeName;

				
				//load project content
				startContentLoader(workFolder);
			}else{
				currentSubOrder.state=OrderState.ERR_WEB;
				currentOrder.state=OrderState.ERR_WEB;
				if(!remoteMode) StateLogDAO.logState(OrderState.ERR_WEB,currentOrder.id,null,'Не найден проект заказа '+currentSubOrder.sub_id.toString()+': '+projectLoader.lastErr);
				releaseWithError(currentOrder,'Не найден проект заказа '+currentSubOrder.sub_id.toString()+': '+projectLoader.lastErr);
				checkQueue();
			}
		}
		
		private var contentLoader:FBookContentDownloadManager;
		private function startContentLoader(workFolder:File):void{
			if(!currentOrder || !currentSubOrder) return;
			contentLoader = new FBookContentDownloadManager(source.fbookService,currentSubOrder.project);
			contentLoader.addEventListener(Event.COMPLETE,contentLoaded);
			contentLoader.addEventListener(ProgressEvent.PROGRESS,contentLoadProgress);
			contentLoader.start(workFolder);
		}

		private function contentLoadProgress(event:ProgressEvent):void{
			_speed=contentLoader.speed;
			dispatchEvent(event.clone());
		}

		public function get speed():Number{
			return _speed;
		}
		
		private function contentLoaded(event:Event):void{
			contentLoader.removeEventListener(Event.COMPLETE,contentLoaded);
			contentLoader.removeEventListener(ProgressEvent.PROGRESS,contentLoadProgress);
			//TODO remove other listeners
			if(!currentOrder || !currentSubOrder || !currentSubOrder.project) return;
			if(currentSubOrder.project.downloadState==TripleState.TRIPLE_STATE_ERR){
				//TODO check auth??
				currentSubOrder.state=OrderState.ERR_FTP;
				currentOrder.state=OrderState.ERR_FTP;
				if(!remoteMode) StateLogDAO.logState(currentOrder.state,currentOrder.id,null,'Ошибка загрузки подзаказа ' +currentSubOrder.sub_id.toString()+' :'+contentLoader.errorText);
				releaseWithError(currentOrder,'Подзаказ ' +currentSubOrder.sub_id.toString()+': '+contentLoader.errorText);
				checkQueue();
			}else{
				currentSubOrder.state=OrderState.FTP_COMPLETE;
				if(!remoteMode) StateLogDAO.logState(currentOrder.state,currentOrder.id,null,'Загружен подзаказ ' +currentSubOrder.sub_id.toString());
				//TODO prepare text images
				nextSubOrder();
			}
		}

		private function releaseWithError(order:Order, errMessage:String):void{
			if(!order) return;
			if(order===currentOrder){
				currentOrder=null;
				currentSubOrder=null;
			}
			removeFromQueue(order);
			dispatchEvent(new ImageProviderEvent(ImageProviderEvent.LOAD_FAULT_EVENT,order,errMessage));
		}

		private function removeFromQueue(order:Order):void{
			if(!order || !queue || queue.length==0) return;
			var idx:int=queue.indexOf(order);
			if(idx!=-1) queue.splice(idx,1);
		}
		
		private function flowError(errMsg:String):void{
			dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,errMsg));
		}
		
		private function onFlowErr(event:ImageProviderEvent):void{
			flowError(event.error);
		}

	}
}