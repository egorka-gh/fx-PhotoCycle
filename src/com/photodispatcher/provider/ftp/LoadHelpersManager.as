package com.photodispatcher.provider.ftp{
	import com.jxl.chat.vo.InstructionConstants;
	import com.jxl.chat.vo.messages.ChatMessageVO;
	import com.jxl.chatserver.events.ServiceEvent;
	import com.jxl.chatserver.mvcs.services.ChatServerService;
	import com.jxl.chatserver.vo.ClientVO;
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.factory.WebServiceBuilder;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.dao.StateLogDAO;
	import com.photodispatcher.service.web.BaseWeb;
	import com.photodispatcher.util.ArrayUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	
	import mx.controls.Alert;
	
	public class LoadHelpersManager extends QueueManager{
		
		private var _localQueues:Array=[];
		public function get localQueues():Array{
			return _localQueues;
		}
		public function set localQueues(value:Array):void{
			if(value){
				_localQueues=value.concat();
			}else{
				_localQueues=[];
			}
		}
		
		private var helpersMap:Dictionary;
		private var chatServer:ChatServerService;
		
		public function LoadHelpersManager(){
			super(null);
			_type=QueueManager.TYPE_REMOTE;
			sourceCaption='Удаленная загрузка';
		}
		
		[Bindable(event="queueLenthChange")]
		override public function get queueLenth():int{
			return connectionsActive;
		}
		
		
		override public function reSync(orders:Array):void{
			trace('LoadHelpersManager reSync ');
			//empty responce from DAO
			if(!chatServer) init();
			if(!orders) return;

			//TODO implement stop load canceled order (skip unfetch or some else)
			var helper:LoadHelper;
			var toStop:Array=[]; //LoadHelper's
			var idx:int;
			var order:Order;
			if(orders.length==0){
				//nothig to process
				//stop all
				if(helpersMap){
					for each(helper in helpersMap){
						if(helper && helper.isBusy) toStop.push(helper);
					}
				}
			}else{
				if(helpersMap){
					for each(helper in helpersMap){
						if(helper && helper.isBusy){
							order=helper.currentOrder;
							if(order){
								idx=ArrayUtil.searchItemIdx('id',order.id,orders);
								if(idx==-1){
									//stop
									toStop.push(helper);
								}else{
									//replace
									orders[idx]=order;
								}
							}
						}
					}
				}
			}
			
			//stop
			for each(helper in toStop){
				if(helper && helper.isBusy) helper.stop();
			}
		}
		
		
		override public function start(resetErrors:Boolean=false):void{
			//if(!chatServer || !chatServer.isOnline) flowError('ChatServer не подключен');
			//reset
			/*
			webErrCounter=0;
			lastWebErrSource=-1;
			webApplicant=null;
			*/
			lastError='';
			downloadCaption='';

			// TODO implement

			if(!chatServer) init();
			_isStarted=true;
			forceStop=false;
			dispatchEvent(new Event('isStartedChange'));
			startNext();
		}
		
		override public function stop():void{
			_isStarted=false;
			forceStop=true;
			var helper:LoadHelper;
			if(helpersMap){
				for each(helper in helpersMap){
					if(helper){
						if(helper.isBusy) helper.stop();
					}
				}
			}
			dispatchEvent(new Event('isStartedChange'));
		}
		

		private function init():void{
			if(chatServer) return;
			chatServer=ChatServerService.instance;
			chatServer.addEventListener(ServiceEvent.CHAT_SERVER_SERVICE_ERROR,onServerError);
			chatServer.addEventListener(ServiceEvent.CHAT_SERVER_SERVICE_USER_ONLINE,onNewHelper);
			chatServer.addEventListener(ServiceEvent.CHAT_SERVER_SERVICE_USER_OFFLINE,onHelperDisconnect);
			chatServer.addEventListener(ServiceEvent.CHAT_SERVER_SERVICE_USER_MESSAGE,onChatMessage);
			
			/*TODO start at application level
			if(!chatServer.isOnline){
				var servIp:String;
				servIp=Context.getAttribute("serverIP");
				if(servIp){
					chatServer.startServer(servIp);
				}
			}
			*/
			helpersMap=new Dictionary();
			if(chatServer.isOnline){
				var arr:Array=chatServer.getClientsByType(ClientVO.TYPE_LOADER);
				arr=arr.concat(chatServer.getClientsByType(ClientVO.TYPE_HELPER));
				var client:ClientVO;
				var helper:LoadHelper;
				for each(client in arr){
					if(client){
						helper=new LoadHelper(client);
						listenHelper(helper);
						helpersMap[client]=helper;
					}
				}
				loadCaption();
			}
		}
		
		override public function destroy():void{
			var helper:LoadHelper;
			if(helpersMap){
				for each(helper in helpersMap){
					if(helper){
						if(helper.isBusy) helper.stop();
						destroyHelper(helper);
					}
				}
				helpersMap=null;
			}
			if(chatServer){
				chatServer.removeEventListener(ServiceEvent.CHAT_SERVER_SERVICE_ERROR,onServerError);
				chatServer.removeEventListener(ServiceEvent.CHAT_SERVER_SERVICE_USER_ONLINE,onNewHelper);
				chatServer.removeEventListener(ServiceEvent.CHAT_SERVER_SERVICE_USER_OFFLINE,onHelperDisconnect);
				chatServer.removeEventListener(ServiceEvent.CHAT_SERVER_SERVICE_USER_MESSAGE,onChatMessage);
				chatServer=null;
			}
			localQueues=[];
		}

		private function onServerError(evt:ServiceEvent):void{
			Alert.show('Ошибка chatServer: '+evt.lastError);
		}
		private function onNewHelper(evt:ServiceEvent):void{
			var client:ClientVO=evt.user;
			if(client && (client.userType==ClientVO.TYPE_LOADER || client.userType==ClientVO.TYPE_HELPER)){
				if(!helpersMap[client]){
					var helper:LoadHelper=new LoadHelper(client);
					listenHelper(helper);
					helpersMap[client]=helper;
					loadCaption();
					startNext();
				}
			}
		}
		
		private function checkUserMode(evt:ServiceEvent):void{
			var client:ClientVO=evt.user;
			var helper:LoadHelper;
			if(client){
				helper=helpersMap[client] as LoadHelper;
				if(helper){
					if(!helper.isBusy && client.userType!=ClientVO.TYPE_LOADER && client.userType!=ClientVO.TYPE_HELPER){
						destroyHelper(helper);
						delete helpersMap[client];
						loadCaption();
					}
				}else{
					onNewHelper(evt);
				}
			}
		}
		
		private function onHelperDisconnect(evt:ServiceEvent):void{
			var helper:LoadHelper=helpersMap[evt.user] as LoadHelper;
			if(helper){
				if(helper.isBusy){
					var order:Order=helper.currentOrder;
					if(order){
						//release order
						resetOrderState(order);
						unFetch(order);
					}
				}
				destroyHelper(helper);
				delete helpersMap[evt.user];
			}
			loadCaption();
			startNext();
		}
		private function onChatMessage(evt:ServiceEvent):void{
			var msg:ChatMessageVO= evt.message;
			if(!msg) return;
			switch(msg.instructions){
				case InstructionConstants.CLIENT_SET_USERTYPE:
					//add if new
					checkUserMode(evt);
					break;
			}
			var helper:LoadHelper=helpersMap[evt.user] as LoadHelper;
			if(helper) helper.processMessage(evt.message);
		}

		private function listenHelper(helper:LoadHelper):void{
			if(!helper) return;
			helper.addEventListener(ImageProviderEvent.FLOW_ERROR_EVENT, onFlowError);
			helper.addEventListener(ImageProviderEvent.LOAD_FAULT_EVENT, onLoadFault);
			helper.addEventListener(ImageProviderEvent.ORDER_LOADED_EVENT, onLoaded);
			helper.addEventListener(Event.CHANGE,onProgress);
		}
		private function destroyHelper(helper:LoadHelper):void{
			if(!helper) return;
			helper.removeEventListener(ImageProviderEvent.FLOW_ERROR_EVENT, onFlowError);
			helper.removeEventListener(ImageProviderEvent.LOAD_FAULT_EVENT, onLoadFault);
			helper.removeEventListener(ImageProviderEvent.ORDER_LOADED_EVENT, onLoaded);
			helper.removeEventListener(Event.CHANGE, onProgress);
		}

		//private var webApplicant:Order;
		//private var webErrCounter:int=0;
		//private var lastWebErrSource:int=-1;

		private function startNext():void{
			//if(webApplicant || !isStarted || forceStop) return;
			if(!isStarted || forceStop) return;
			var helper:LoadHelper=freeHelper;
			if(helper){
				var newOrder:Order=fetchNext();
				helper.post(newOrder);
			}
			loadCaption();
			/*
			//TODO implement
			//TODO fix & skip source ws web error
			if(newOrder && !webApplicant){
				trace('LoadHelpersManager web request '+newOrder.ftp_folder);
				//check state on site
				webApplicant=newOrder;
				webApplicant.state=OrderState.FTP_WEB_CHECK;
				var w:BaseWeb= WebServiceBuilder.build(source);
				w.addEventListener(Event.COMPLETE,getOrderHandle);
				w.getOrder(newOrder);
			}
			*/
		}
		
		private function get freeHelper():LoadHelper{
			//get builder
			var h:LoadHelper;
			var helper:LoadHelper;
			var skipped:LoadHelper;
			var toKill:Array=[];
			for each(h in helpersMap){
				if(h && !h.isBusy){
					if(h.client.userType==ClientVO.TYPE_LOADER || h.client.userType==ClientVO.TYPE_HELPER){
						//can use
						if(h.skipOnReject){
							h.skipOnReject=false;
							skipped=h;
						}else{
							if(!helper || h.lastUsageDate.time<helper.lastUsageDate.time){
								helper=h;
							}
						}
					}else{
						//remove from map
						toKill.push(h);
					}
				}
			}
			for each(h in toKill){
				if(h){
					destroyHelper(h);
					delete helpersMap[h.client];
				}
			}
			if(!helper) helper=skipped;
			return helper;
		}
		
		override public function fetchNext():Order{
			var q:QueueManager;
			var queue:QueueManager;
			var order:Order;
			//get longest local queue
			for each (q in localQueues){
				if(q && q.queueLenth>0){
					/*
					if(q.source.id==lastWebErrSource){
						//reset & skip
						lastWebErrSource=-1;
					}else if(!queue || q.queueLenth>queue.queueLenth){
						queue=q;
					}
					*/
					if(!queue || q.queueLenth>queue.queueLenth){
						queue=q;
					}
				}
			}
			//fetch order
			if(queue){
				order=queue.fetchNext();
			}
			return order;
		}
		
		override public function unFetch(order:Order):void{
			if(!order) return;
			var q:QueueManager;
			var queue:QueueManager;
			for each (q in localQueues){
				if(q && q.source.id==order.source){
					queue=q;
					break;
				}
			}
			if(queue) queue.unFetch(order);
		}

		/*
		private function getOrderHandle(e:Event):void{
			var pw:BaseWeb=e.target as BaseWeb;
			pw.removeEventListener(Event.COMPLETE,getOrderHandle);
			if(!webApplicant){
				//removed by sync or some else
				//start next?
				startNext();
				return;
			}
			if(webApplicant.state!=OrderState.FTP_WEB_CHECK;) return; //wrong sequence
			
			if(pw.hasError){
				trace('LoadHelpersManager getOrderHandle web check order err: '+pw.errMesage);
				webErrCounter++;
				lastWebErrSource=webApplicant.source;
				webApplicant.state=OrderState.ERR_WEB;
				StateLogDAO.logState(OrderState.ERR_WEB,webApplicant.id,'','Ошибка проверки на сайте: '+pw.errMesage);
				unFetch(webApplicant);
				webApplicant=null;
				//to prevent cycle web check when network error or offline
				if(webErrCounter>WEB_ERRORS_LIMIT){
					flowError('Ошибка web: '+pw.errMesage);
				}else{
					startNext();
				}
				return;
			}
			webErrCounter=0;
			if(pw.isValidLastOrder(true)){
				//post
				trace('LoadHelpersManager.getOrderHandle; web check Ok; attempt post to remote loader '+webApplicant.ftp_folder);
				webApplicant.state=OrderState.FTP_WEB_OK;
				var helper:LoadHelper=freeHelper;
				if(!helper){
					unFetch(webApplicant);
					webApplicant=null;
					return;
				}
				helper.post(webApplicant);
				webApplicant=null;
				loadCaption();
				return;
			}else{
				//mark as canceled
				trace('LoadHelpersManager.getOrderHandle; web check fault; order canceled '+webApplicant.ftp_folder);
				webApplicant.state=OrderState.CANCELED;
				webApplicant=null;
				startNext();
			}
		}
		*/
		
		private function loadCaption():void{
			//TODO show helpers usege & order list & show files progres & speed
			var newDownloadCaption:String='';
			var newSpeed:Number=0;
			var newConnectionsLimit:int=0;
			var newConnectionsActive:int=0;
			var filesTotal:int=0;
			var filesDone:int=0;

			var helper:LoadHelper;
			
			for each(helper in helpersMap){
				if(helper){
					newConnectionsLimit++;
					if(helper.isBusy){
						newConnectionsActive++;
						filesTotal+=helper.filesTotal;
						filesDone+=helper.filesDone;
						newSpeed+=helper.speed;
						if(helper.currentOrder){
							if(newDownloadCaption) newDownloadCaption+=', ';
							newDownloadCaption+=helper.currentOrder.ftp_folder;
						}
					}
				}
			}
			connectionsLimit=newConnectionsLimit;
			connectionsActive=newConnectionsActive;
			connectionsFree=newConnectionsLimit-newConnectionsActive;
			downloadCaption=newDownloadCaption;
			speed=newSpeed;
			dispatchEvent(new Event('queueLenthChange'));
			dispatchEvent(new ProgressEvent(ProgressEvent.PROGRESS,false,false,filesDone,filesTotal));
		}
		
		private function onFlowError(event:ImageProviderEvent):void{
			var helper:LoadHelper=event.target as LoadHelper;
			var order:Order;
			if(helper){
				order=helper.currentOrder;
				helper.reset();
				if(order && order.state!=OrderState.CANCELED){
					//release order, skip canceled
					resetOrderState(order);
					unFetch(order);
				}
			}
			loadCaption();
			flowError(event.error);
			startNext();
		}
		
		private function onLoadFault(event:ImageProviderEvent):void{
			var helper:LoadHelper=event.target as LoadHelper;
			var order:Order=event.order;
			if(order){
				if(order.state>=0){
					order.state=OrderState.ERR_FTP;
					StateLogDAO.logState(OrderState.ERR_FTP,order.id,'',event.error);
				}
				order.setErrLimit();
				unFetch(order);
			}
			if(helper) helper.reset();
			loadCaption();
			startNext();
		}
		
		private function onLoaded(event:ImageProviderEvent):void{
			var helper:LoadHelper=event.target as LoadHelper;
			if(helper) helper.reset();
			loadCaption();
			startNext();
			dispatchEvent(event.clone());
		}

		private function onProgress(event:Event):void{
			loadCaption();
		}
		
	}
}