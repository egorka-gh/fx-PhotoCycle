package com.photodispatcher.provider.ftp.remote{
	import com.jxl.chat.vo.ChatPretender;
	import com.jxl.chat.vo.InstructionConstants;
	import com.jxl.chat.vo.messages.LoadMessageVO;
	import com.jxl.chat.vo.messages.MessageTypes;
	import com.jxl.chatclient.events.ServiceEvent;
	import com.jxl.chatclient.mvcs.services.ChatService;
	import com.photodispatcher.context.Context;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.event.LoadProgressEvent;
	import com.photodispatcher.model.Order;
	import com.photodispatcher.model.OrderState;
	import com.photodispatcher.model.Source;
	import com.photodispatcher.model.SourceType;
	import com.photodispatcher.provider.ftp.QueueManager;
	import com.photodispatcher.provider.ftp.QueueManagerFBManual;
	
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	
	public class RemoteFtpManager extends EventDispatcher{
		
		private var _chatService:ChatService;
		[Bindable]
		public var loader:QueueManager;
		private var currentOrder:Order;
		private var isRunning:Boolean;
		
		public function RemoteFtpManager(){
			super();
		}
		
		public function set chatService(service:ChatService):void{
			if(_chatService){
				// stop listen
				_chatService.removeEventListener(ServiceEvent.JOINED_CHAT, onConnected);
				_chatService.removeEventListener(ServiceEvent.DISCONNECTED, onDisconnected);
				_chatService.removeEventListener(ServiceEvent.USERNAME_TAKEN, onDisconnected);
				_chatService.removeEventListener(ServiceEvent.ERROR, onError);
				_chatService.removeEventListener(ServiceEvent.CHAT_MESSAGE, onChatMessage);
			}
			_chatService=service;
			if(_chatService){
				//start listen
				_chatService.addEventListener(ServiceEvent.JOINED_CHAT, onConnected);
				_chatService.addEventListener(ServiceEvent.DISCONNECTED, onDisconnected);
				_chatService.addEventListener(ServiceEvent.USERNAME_TAKEN, onDisconnected);
				_chatService.addEventListener(ServiceEvent.ERROR, onError);
				_chatService.addEventListener(ServiceEvent.CHAT_MESSAGE, onChatMessage);
			}
		}

		private function onConnected(evt:ServiceEvent):void{
			//do nothing
		}
		private function onDisconnected(evt:ServiceEvent):void{
			destroyLoader();
		}
		private function onError(evt:ServiceEvent):void{
			destroyLoader();
		}

		private function onChatMessage(evt:ServiceEvent):void{
			//TODO implement
			var msg:LoadMessageVO;
			if(evt.chatMessage.type==MessageTypes.LOAD) msg=evt.chatMessage as LoadMessageVO;
			if(!msg) return;
			switch(msg.instructions){
				case InstructionConstants.SERVER_LOAD_POST:
					if(isRunning){
						_chatService.sendLoadMessage(InstructionConstants.CLIENT_LOAD_REJECT,'Занят загрузкой. заказ: ' +(currentOrder?currentOrder.id:''));
						return;
					}
					currentOrder=msg.order;
					if(!currentOrder){
						_chatService.sendLoadMessage(InstructionConstants.CLIENT_LOAD_REJECT,'Ошибка. Не задан заказ (null)',null,'null');
						return;
					}
					currentOrder.state=OrderState.WAITE_FTP;
					_chatService.sendLoadMessage(InstructionConstants.CLIENT_LOAD_CONFIRM,ChatPretender.postConfirmMessage()+currentOrder.id);
					startLoad();
					break;
				case InstructionConstants.SERVER_LOAD_STOP:
					var order:Order=currentOrder;
					if(loader) loader.stop(); 
					destroyLoader();
					_chatService.sendLoadMessage(InstructionConstants.CLIENT_LOAD_REJECT,'Остановлена загрузка. заказ: ' +(order?order.id:''));
					break;
			}
		}

		private function startLoad():void{
			if(!currentOrder) return;
			var source:Source=Context.getSource(currentOrder.source);
			if(!source){
				_chatService.sendLoadMessage(InstructionConstants.CLIENT_LOAD_REJECT,'Ошибка инициализации. Не задан источник (null)');
			}
			isRunning=true;
			//create loader
			if(source.type_id==SourceType.SRC_FBOOK_MANUAL){
				loader=new QueueManagerFBManual(source,true);
			}else{
				loader=new QueueManager(source,true);
			}

			//listen
			loader.addEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onOrderLoaded);
			loader.addEventListener(ImageProviderEvent.FLOW_ERROR_EVENT, onFlowErr);
			loader.addEventListener(ImageProviderEvent.LOAD_FAULT_EVENT,onDownloadFault);
			loader.addEventListener(ProgressEvent.PROGRESS,onLoadProgress);
			loader.reSync([currentOrder]);
			loader.start();
		}
		
		private function destroyLoader():void{
			isRunning=false;
			//listen
			if(loader){
				loader.destroy();
				loader.removeEventListener(ImageProviderEvent.ORDER_LOADED_EVENT,onOrderLoaded);
				loader.removeEventListener(ImageProviderEvent.FLOW_ERROR_EVENT, onFlowErr);
				loader.removeEventListener(ImageProviderEvent.LOAD_FAULT_EVENT,onDownloadFault);
				loader.removeEventListener(ProgressEvent.PROGRESS,onLoadProgress);
			}
			currentOrder=null;
			loader=null;
		}
		
		private function onFlowErr(event:ImageProviderEvent):void{
			_chatService.sendLoadMessage(InstructionConstants.CLIENT_LOAD_REJECT,'Ошибка загрузки: '+event.error+'. Заказ: '+currentOrder.id,currentOrder,event.error);
			destroyLoader();
		}

		private function onOrderLoaded(event:ImageProviderEvent):void{
			_chatService.sendLoadMessage(InstructionConstants.CLIENT_LOAD_COMPLETE,'Завершена загрузка. Заказ: '+event.order.id,event.order);
			destroyLoader();
		}

		private function onDownloadFault(event:ImageProviderEvent):void{
			_chatService.sendLoadMessage(InstructionConstants.CLIENT_LOAD_COMPLETE,'Ошибка загрузки: '+event.error+'. Заказ: '+currentOrder.id,currentOrder,event.error);
			destroyLoader();
		}

		private function onLoadProgress(evt:ProgressEvent):void{
			var speed:Number=0;
			if(evt is LoadProgressEvent) speed=(evt as LoadProgressEvent).speed;
			_chatService.sendLoadProgressMessage(evt.bytesLoaded,evt.bytesTotal,speed);
		}
	}
}