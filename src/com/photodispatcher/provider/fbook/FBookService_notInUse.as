package com.photodispatcher.provider.fbook{
	import com.akmeful.fotokniga.net.AuthService;
	import com.akmeful.json.JsonUtil;
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.Suborder;
	import com.photodispatcher.model.dao.StateLogDAO;
	import com.photodispatcher.provider.ImageProvider;
	import com.photodispatcher.provider.fbook.download.FBookContentDownloadManager;
	import com.photodispatcher.provider.fbook.event.ItemDownloadedEvent;
	import com.photodispatcher.util.StrUtil;
	
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import mx.controls.Alert;
	import mx.rpc.AsyncResponder;
	import mx.rpc.AsyncToken;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import com.photodispatcher.provider.fbook.download.FBookProjectLoader;
	
	public class FBookService_notInUse extends ImageProvider{
		//TODO kill not in use
		/**
		 *
		 * used only as subservice
		 * skips web check
		 *  
		 * @param source
		 * 
		 */		
		public function FBookService_notInUse(source:Source=null){
			super(source);
		}

		/**
		 * TODO
		 * resync - add suborders
		 * login
		 * detect type/ load project
		 * buld texts
		 * load images
		 * create printgruops 
		 * 
		 */
		
		private var token:AsyncToken;
		private var isLoading:Boolean=false;
		
		/**
		 *4 subservice mode 
		 * order local folder
		 * @param path
		 * 
		 */		
		public function setLocalFolder(path:String):void{
			localFolder=path;
		}
		
		override public function start():void{
			startMeter();
			if(!source || !source.fbookService) return;
			trace('FBookService starting for '+source.fbookService.url);
			
			/* 4 regular service mode 
			//detect lockal folder
			var dstFolder:String=Context.getAttribute('workFolder');
			if(!dstFolder){
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR,'Не задана рабочая папка'));
				return;
			}
			var fl:File=new File(dstFolder);
			if(!fl.exists || !fl.isDirectory){
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR,'Не задана рабочая папка'));
				return;
			}
			//check create source folder
			fl=fl.resolvePath(StrUtil.toFileName(source.name));
			try{
				if(!fl.exists) fl.createDirectory();
			}catch(e:Error){
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR,'Ошибка доступа. Папка: '+fl.nativePath));
				return;
			}
			localFolder=fl.nativePath;
			*/
			
			//chek local folder (subservice mode)
			if(!localFolder){
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,'Не задана рабочая папка'));
				return;
			}
			var fl:File=new File(localFolder);
			if(!fl.exists || !fl.isDirectory){
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,'Не задана рабочая папка'));
				return;
			}
			
			//attempt to login
			var auth:AuthService;
			if(!AuthService.instance){
				var auth:AuthService= new AuthService();
				auth.method='POST';
				auth.resultFormat='text';
			}
			auth.baseUrl=source.fbookService.url;
			token=auth.siteLogin(source.fbookService.user,source.fbookService.pass);
			token.addResponder(new AsyncResponder(login_ResultHandler,login_FaultHandler));
		}
		protected function login_ResultHandler(event:ResultEvent, token:AsyncToken):void {
			var r:Object = JsonUtil.decode(event.result as String);
			if(r.result){
				//start service
				_isStarted=true;
				forceStop=false;
				dispatchEvent(new Event('isStartedChange'));
				checkQueue();
			} else {
				_isStarted=false;
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,'Ошибка подключения к '+source.fbookService.url));
			}
			token=null;
		}
		protected function login_FaultHandler(event:FaultEvent, token:AsyncToken):void {
			_isStarted = false;
			dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,'Ошибка подключения к '+source.fbookService.url));
			token=null;
		}

		
		
		
		override public function stop():void{
			_isStarted=false;
			forceStop=true;
			getProjectOrderId='';
			currentProject=null;
			

			if(projectLoader){
				projectLoader.removeEventListener(Event.COMPLETE, onProjectLoaded);
				projectLoader=null;
			}
			var order:Order;
			//reset runtime states
			for each(order in queue){
				if(order){
					/*TODO
					if(order.state==OrderState.FTP_WEB_CHECK || order.state==OrderState.FTP_WEB_OK || order.state==OrderState.FTP_LIST){
						order.state=order.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
					}
					*/
				}
			}
			
			//TODO stop download
			/*
			for each(o in downloadOrders){
				order=o as Order;
				if(order){
					order.ftpQueue=[];
					order.printGroups=[];
					if(order.ftpForwarded){
						order.state=OrderState.FTP_FORWARD;
						//foreOrders.unshift(order);
					}else{
						order.state=OrderState.WAITE_FTP;
					}
					queue.unshift(order);
				}
			}
			*/
			downloadOrders=[];
			isLoading=false;
			
			dispatchEvent(new Event('queueLenthChange'));
			dispatchEvent(new Event('processingLenthChange'));
			/*TODO
			loadProgress();
			*/
			
			trace('FBookService stop '+source.ftpService.url);
			stopMeter();
			dispatchEvent(new Event('isStartedChange'));
			//log out
			AuthService.instance.siteLogout();
		}

		private var getProjectOrderId:String;
		private var projectLoader:FBookProjectLoader;
		
		private function checkQueue():void{
			if(!isStarted || forceStop || isLoading) return;
			if(getProjectOrderId) return;
			var newOrder:Order;
			var ord:Order;
			//chek queue
			for each (ord in queue){
				if(ord){
					if(ord.state>0){
						if(ord.state==OrderState.WAITE_FTP || ord.state==OrderState.FTP_FORWARD){
							if(!newOrder){
								newOrder=ord;
							}else if(!newOrder.ftpForwarded && ord.ftpForwarded){
								newOrder=ord;
							}
						}
					}else if(ord.state!=OrderState.ERR_WRITE_LOCK){
						//reset error
						ord.state=ord.ftpForwarded?OrderState.FTP_FORWARD:OrderState.WAITE_FTP;
					}
				}
			}
			
			if(newOrder){
				trace('FBookService.checkQueue get project '+newOrder.id);
				getProjectOrderId=newOrder.id;
				newOrder.state=OrderState.FTP_GET_PROJECT;
				//attempt to get project
				if(!projectLoader){
					projectLoader= new FBookProjectLoader(source);
					projectLoader.addEventListener(Event.COMPLETE, onProjectLoaded);
				}
				currentProject=null;//????
				projectLoader.fetchProject(getProjectId(newOrder));
			}
		}

		private var currentProject:FBookProject;
		
		private function onProjectLoaded(event:Event):void{
			var order:Order;
			if(!getProjectOrderId) return;
			var project:FBookProject=projectLoader.lastFetchedProject;
			if(project){
				//chek create folder
				var file:File=new File(localFolder);
				file.resolvePath(project.id.toString());
				try{
					if(file.exists){
						if(file.isDirectory){
							file.deleteDirectory(true);
						}else{
							file.deleteFile();
						}
					}
					file.createDirectory();
					project.outFolder=file.nativePath;
					//create subfolders
					file=file.resolvePath(FBookProject.SUBDIR_WRK);
					file.createDirectory();
					project.workFolder=file.nativePath;
					//create subdirs
					var parent:File=file;
					var subDir:String;
					for each (subDir in FBookProject.getWorkSubDirs()){
						if (subDir){
							file=parent.resolvePath(subDir);
							file.createDirectory();
						}
					}
				}catch(err:Error){
					order=getOrderById(getProjectOrderId);
					order.state=OrderState.ERR_FILE_SYSTEM;
					StateLogDAO.logState(OrderState.ERR_FILE_SYSTEM,getOrderId(order),'','Папка: '+file.nativePath+' '+err.message); 
					dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,'Ошибка доступа к папке заказа '+getProjectOrderId+' Папка: '+file.nativePath+' '+err.message));
					//reset
					getProjectOrderId='';
					//TODO checkQueue in regular service
					return;
				}
				currentProject=project;
				//TODO load project content
				startContentLoader();
			}else{
				order=getOrderById(getProjectOrderId);
				order.state=OrderState.ERR_WEB;
				StateLogDAO.logState(OrderState.ERR_WEB,getOrderId(order),'','Не найден проект заказа: '+projectLoader.lastErr); 
				dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,'Не найден проект заказа '+getProjectOrderId+' ('+projectLoader.lastErr+')'));
				//reset
				getProjectOrderId='';
				//TODO checkQueue in regular service
			}
		}

		private var contentLoader:FBookContentDownloadManager;
		private function startContentLoader():void{
			contentLoader = new FBookContentDownloadManager(source.fbookService,currentProject) ;
			contentLoader.addEventListener(Event.COMPLETE,contentLoaded);
			//TODO implement
			//contentLoader.addEventListener(ItemDownloadedEvent.ITEM_DOWNLOADED, contentLoadProgress);
			//TODO implement init progress
			//dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,stepsCompleted, stepsTotal));
			contentLoader.start();

		}

		private function contentLoaded(event:Event):void{
			contentLoader.removeEventListener(Event.COMPLETE,contentLoaded);
			//TODO remove other listeners
			if (!contentLoader.hasError){
				currentProject.downloadState=TripleState.TRIPLE_STATE_OK;
				/*
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,stepsCompleted, stepsTotal));
				//buildScripts();
				if(book.scriptState==TRIPLE_STATE_NON) buildScripts();
				if (continuousProgressing) make();
				*/
			}else if(!contentLoader.hasFatalError()){
				currentProject.downloadState=TripleState.TRIPLE_STATE_WARNING;
				/*
				//+1 files loaded
				stepsCompleted++;
				dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,stepsCompleted, stepsTotal));
				//buildScripts();
				if(book.scriptState==TRIPLE_STATE_NON) buildScripts();
				if (continuousProgressing) make();
				*/
			}else{
				//TODO check auth
				currentProject.downloadState=TripleState.TRIPLE_STATE_ERR;
				//dispatchEvent(new Event(Event.COMPLETE));
			}
			trace('filesLoaded'); 
		}

		
		private function getOrderId(order:Order):String{
			if(order is Suborder){
				return (order as Suborder).order_id;
			}else{
				return order.id; 
			}
		}

		private function getProjectId(order:Order):int{
			return int(order.src_id); 
		}
	}
}