package com.photodispatcher.provider.fbook.download{
	//import com.akmeful.fotokniga.net.AuthService;
	import com.akmeful.json.JsonUtil;
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.mysql.entities.BookSynonym;
	import com.photodispatcher.model.mysql.entities.ContentFilter;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderExtraInfo;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceType;
	import com.photodispatcher.model.mysql.entities.StateLog;
	import com.photodispatcher.model.mysql.entities.SubOrder;
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
		protected var _isStarted:Boolean=false;
		protected var localFolder:String;
		protected var forceStop:Boolean=false;
		
		/*
		*orders Queue
		*/
		private var queue:Array=[];
		[Bindable]
		public var currentOrder:Order;
		private var currentSubOrder:SubOrder;

		private var projectLoader:FBookProjectLoader;
		private var _speed:Number=0;
		
		[Bindable(event="queueLenthChange")]
		public function get queueLenth():int{
			return queue.length;
		}

		public function FBookDownloadManager(source:Source){
			super(null);
			this.source=source;
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
			var file:File=new File(localFolder);
			if(!file.exists || !file.isDirectory){
				flowError('Не верная рабочая папка');
				return false;
			}
			//use main login, no auth needed
			_isStarted=true;
			checkQueue();
/*
			if(source.type == SourceType.SRC_PROFOTO){
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
*/
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
			return o!=null && source && o.source==source.id && (o.state==OrderState.FTP_WAITE || o.state==OrderState.FTP_CAPTURED);
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

		public function download(order:Order):void{
			var so:SubOrder;
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
			trace('FBookDownloadManager check queue');
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
				trace('FBookDownloadManager start dload order '+newOrder.id);
				currentOrder=newOrder;

				//clear file system
				var file:File=new File(localFolder);
				file=file.resolvePath(currentOrder.ftp_folder);
				try{
					if(file.exists && !file.isDirectory) file.deleteFile();
					if(!currentOrder.resume_load){
						if(file.exists && file.isDirectory) file.deleteDirectory(true);
						currentOrder.resume_load=true;
					}
					file.createDirectory();
				}catch(error:Error){}

				currentOrder.state=OrderState.FTP_LOAD;
				StateLog.log(currentOrder.state,currentOrder.id,'','Загрузка подзаказов');
				nextSubOrder();
			}else{
				trace('FBookDownloadManager nothing to start recheck queue');
				checkQueue();
			}
		}
		
		private function nextSubOrder():void{
			var so:SubOrder;
			var vsErr:SubOrder;
			var toLoad:SubOrder;
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
				trace('FBookDownloadManager nextSubOrder order complite '+currentOrder.id);
				//currentOrder completed
				currentOrder.state=OrderState.FTP_COMPLETE;
				currentOrder.resetErrCounter();
				removeFromQueue(currentOrder);
				StateLog.log(currentOrder.state, currentOrder.id,'','Завершена загрузка подзаказов'); 
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.ORDER_LOADED_EVENT,currentOrder));
				currentOrder=null;
				currentSubOrder=null;
				dispatchEvent(new Event('queueLenthChange'));
				checkQueue();
				return;
			}
			currentSubOrder=toLoad;
			currentSubOrder.projects=[];
			trace('FBookDownloadManager nextSubOrder get project suborder '+currentSubOrder.sub_id);
			//load project
			currentSubOrder.state=OrderState.FTP_GET_PROJECT;
			
			if(!projectLoader){
				projectLoader= new FBookProjectLoader(source);
				projectLoader.addEventListener(Event.COMPLETE, onProjectLoaded);
			}
			//projectLoader.fetchProject(int(currentSubOrder.sub_id), currentSubOrder.native_type);
			if(!loadNextProject()){
				currentSubOrder.state=OrderState.ERR_WEB;
				currentOrder.state=OrderState.ERR_WEB;
				StateLog.log(OrderState.ERR_WEB,currentOrder.id,currentSubOrder.sub_id,'Пустой список id проектов '+currentSubOrder.sub_id);
				releaseWithError(currentOrder,'Пустой список id проектов '+currentSubOrder.sub_id);
				checkQueue();
			}
		}
		
		private function loadNextProject():Boolean{
			if(!currentSubOrder || !currentOrder) return false;
			if(!currentSubOrder.projectIds || currentSubOrder.projectIds.length==0) return false;
			var nextId:String=currentSubOrder.projectIds.shift();
			if(!nextId) return loadNextProject();
			if(!projectLoader){
				projectLoader= new FBookProjectLoader(source);
				projectLoader.addEventListener(Event.COMPLETE, onProjectLoaded);
			}
			projectLoader.fetchProject(int(nextId), currentSubOrder.native_type);
			return true;
		}
		
		private function onProjectLoaded(event:Event):void{
			//var order:Order;
			if(!currentSubOrder || !currentOrder) return;
			var project:FBookProject=projectLoader.lastFetchedProject;
			
			if(project){
				//currentSubOrder.project=project;
				currentSubOrder.projects.push(project);
				trace('FBookDownloadManager nextSubOrder get project complite suborder: '+currentSubOrder.sub_id+', projId: '+project.id);
				if(loadNextProject()){
					//fetching next
					return;
				}
				//all projects fetched
				//chek create suborder folder
				var workFolder:File;
				var file:File=new File(localFolder);
				
				file=file.resolvePath(currentOrder.ftp_folder+File.separator+currentSubOrder.ftp_folder);
				try{
					/*/
					if(file.exists){
						if(file.isDirectory){
							file.deleteDirectory(true);
						}else{
							file.deleteFile();
						}
					}
					*/
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
					StateLog.log(currentOrder.state,currentOrder.id,currentSubOrder.sub_id,'Папка: '+file.nativePath+' '+err.message); 
					if(currentOrder.exceedErrLimit) releaseWithError(currentOrder,err.message);
					currentOrder=null;
					currentSubOrder=null;
					checkQueue();
					return;
				}
				
				
				//fill extra info
				/*
				if(source.type==SourceType.SRC_FOTOKNIGA && currentOrder.extraInfo){
					//clone order extraInfo
					currentSubOrder.extraInfo= currentOrder.extraInfo.clone();
				}else{
				*/
					currentSubOrder.extraInfo= new OrderExtraInfo();
					var calcTitle:String='Онлайн редактор';
					if(project.typeCaption) calcTitle=calcTitle +' '+project.typeCaption;
					if(project.programmAlias){
						calcTitle=calcTitle +' '+project.programmAlias;
						currentSubOrder.extraInfo.calc_type=project.programmAlias;
					}
					currentSubOrder.extraInfo.calcTitle=calcTitle;
					currentSubOrder.extraInfo.dateIn=project.project.createDate;
					currentSubOrder.extraInfo.endpaper=project.endpaperName;
					currentSubOrder.extraInfo.interlayer=project.interlayerName;
					currentSubOrder.extraInfo.cover=project.coverName;
					currentSubOrder.extraInfo.coverMaterial=project.coverMaterial;
					currentSubOrder.extraInfo.format=project.formatName;
					currentSubOrder.extraInfo.corner_type=project.cornerTypeName;
					currentSubOrder.extraInfo.book_type=project.bookType;
					currentSubOrder.extraInfo.books=currentSubOrder.prt_qty;
				/*}*/

				//check content filter
				var cFilter:ContentFilter=Context.getAttribute('contentFilter') as ContentFilter;
				var skip:Boolean=false;
				if(cFilter && cFilter.id!=0){
					skip=project.bookType==0 && !cFilter.is_photo_allow; 
					skip=project.bookType!=0 && !cFilter.is_retail_allow;
					if(!skip && project.bookType!=0 && cFilter.is_alias_filter){
						var bs:BookSynonym=BookSynonym.translateAlias(project.printAlias)
						if(bs) skip=!cFilter.allowAlias(bs.id);
					}
					if(skip){
						currentSubOrder.state=OrderState.SKIPPED;
						StateLog.log(currentSubOrder.state ,currentSubOrder.order_id, currentSubOrder.sub_id,''); 
						nextSubOrder();
						return;
					}
				}

				//load project content
				startContentLoader(workFolder);
			}else{
				source.fbookSid='';
				currentSubOrder.state=OrderState.ERR_WEB;
				currentOrder.state=OrderState.ERR_WEB;
				StateLog.log(OrderState.ERR_WEB,currentOrder.id,currentSubOrder.sub_id,'Не найден проект заказа '+currentSubOrder.sub_id+': '+projectLoader.lastErr);
				releaseWithError(currentOrder,'Не найден проект заказа '+currentSubOrder.sub_id+': '+projectLoader.lastErr);
				checkQueue();
			}
		}
		
		private var contentLoader:FBookContentDownloadManager;
		private function startContentLoader(workFolder:File):void{
			if(!currentOrder || !currentSubOrder) return;
			trace('FBookDownloadManager startContentLoader, suborder '+currentSubOrder.sub_id);
			contentLoader = new FBookContentDownloadManager(source.fbookService,currentSubOrder);
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
			trace('FBookDownloadManager content loaded, suborder '+currentSubOrder.sub_id);
			contentLoader.removeEventListener(Event.COMPLETE,contentLoaded);
			contentLoader.removeEventListener(ProgressEvent.PROGRESS,contentLoadProgress);
			//TODO remove other listeners
			if(!currentOrder || !currentSubOrder) return;
			//if(currentSubOrder.project.downloadState==TripleState.TRIPLE_STATE_ERR){
			if(contentLoader.hasFatalError()){
				//TODO check auth??
				source.fbookSid='';
				currentSubOrder.state=OrderState.ERR_FTP;
				currentOrder.state=OrderState.ERR_FTP;
				StateLog.log(currentOrder.state,currentOrder.id,currentSubOrder.sub_id,'Ошибка загрузки подзаказа ' +currentSubOrder.sub_id+' :'+contentLoader.errorText);
				releaseWithError(currentOrder,'Подзаказ ' +currentSubOrder.sub_id+': '+contentLoader.errorText);
				checkQueue();
			}else{
				currentSubOrder.state=OrderState.FTP_COMPLETE;
				StateLog.log(currentOrder.state,currentOrder.id,currentSubOrder.sub_id,'Загружен подзаказ ' +currentSubOrder.sub_id);
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