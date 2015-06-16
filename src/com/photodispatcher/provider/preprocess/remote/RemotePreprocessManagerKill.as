package com.photodispatcher.provider.preprocess.remote{
	import com.jxl.chat.vo.ChatPretender;
	import com.jxl.chat.vo.InstructionConstants;
	import com.jxl.chat.vo.messages.BuildMessageVO;
	import com.jxl.chat.vo.messages.MessageTypes;
	import com.jxl.chatclient.events.ServiceEvent;
	import com.jxl.chatclient.mvcs.services.ChatService;
	import com.photodispatcher.event.OrderBuildEvent;
	import com.photodispatcher.event.OrderBuildProgressEvent;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.provider.preprocess.OrderBuilderLocal;
	
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.ProgressEvent;
	
	public class RemotePreprocessManagerKill extends EventDispatcher{
		
		[Bindable]
		public var lastError:String;
		[Bindable]
		public var isRunning:Boolean=false;
		[Bindable]
		public var progressCaption:String='';

		public var canBuild:Boolean=false;

		private var builder:OrderBuilderLocal;
		private var _chatService:ChatService;

		[Bindable]
		public var lastOrder:Order;

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

		public function RemotePreprocessManagerKill(){
			super();
		}
		
		private function onConnected(evt:ServiceEvent):void{
			if(!builder) createBuilder();
		}
		private function onDisconnected(evt:ServiceEvent):void{
			destroyBuilder();
		}
		private function onError(evt:ServiceEvent):void{
			lastError=evt.lastError;
			destroyBuilder();
		}
		private function onChatMessage(evt:ServiceEvent):void{
			//TODO implement
			var msg:BuildMessageVO;
			if(evt.chatMessage.type==MessageTypes.BUILD) msg=evt.chatMessage as BuildMessageVO;
			if(!msg) return;
			switch(msg.instructions){
				case InstructionConstants.SERVER_BUILD_POST:
					if(!canBuild){
						_chatService.sendBuildMessage(InstructionConstants.CLIENT_BUILD_REJECT,'Не закончена инициализация приложения.');
						return;
					}
					if(!builder) createBuilder();
					if(builder.isBusy){
						_chatService.sendBuildMessage(InstructionConstants.CLIENT_BUILD_REJECT,'Занят обработкой. Заказ: '+(builder.lastOrder?builder.lastOrder.id:''));
						return;
					}
					lastOrder=msg.order;
					if(!lastOrder){
						_chatService.sendBuildMessage(InstructionConstants.CLIENT_BUILD_REJECT,'Ошибка. Не задан заказ (null)');
						return;
					}
					//_chatService.sendBuildMessage(InstructionConstants.CLIENT_BUILD_CONFIRM,'Принят на обработку заказ '+lastOrder.id);
					_chatService.sendBuildMessage(InstructionConstants.CLIENT_BUILD_CONFIRM,ChatPretender.postConfirmMessage()+lastOrder.id);
					lastError='';
					builder.build(lastOrder);
					isRunning=true;
					break;
			}
		}
		
		private function createBuilder():void{
			builder= new OrderBuilderLocal(false);
			builder.addEventListener(OrderBuildEvent.BUILDER_ERROR_EVENT,onBuilderError);
			builder.addEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onOrderPreprocessed);
			builder.addEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
		}

		private function destroyBuilder():void{
			if(!builder) return;
			builder.stop();
			builder.removeEventListener(OrderBuildEvent.BUILDER_ERROR_EVENT,onBuilderError);
			builder.removeEventListener(OrderBuildEvent.ORDER_PREPROCESSED_EVENT, onOrderPreprocessed);
			builder.removeEventListener(ProgressEvent.PROGRESS, onPreprocessProgress);
			builder=null;
			isRunning=false;
		}
		
		private function onPreprocessProgress(e:OrderBuildProgressEvent):void{
			progressCaption=e.caption;
			dispatchEvent(e.clone());
		}

		private function onBuilderError(evt:OrderBuildEvent):void{
			//builder internal error
			lastError=evt.err_msg;
			//send reject
			_chatService.sendBuildMessage(InstructionConstants.CLIENT_BUILD_REJECT,evt.err_msg);
			destroyBuilder();
		}
		private function onOrderPreprocessed(evt:OrderBuildEvent):void{
			if(evt.err<0) lastError=evt.err_msg;
			if(!lastOrder) return;//???
			//order complited
			if(evt.err<0){
				//completed vs error
				if (lastOrder.state!=evt.err) lastOrder.state=evt.err; 
				_chatService.sendBuildMessage(InstructionConstants.CLIENT_BUILD_COMPLETE,'Ошибка подготовки: '+evt.err_msg+'. Заказ: '+lastOrder.id,lastOrder,evt.err_msg);
			}else{
				_chatService.sendBuildMessage(InstructionConstants.CLIENT_BUILD_COMPLETE,'Завершена подготовка. Заказ: '+lastOrder.id,lastOrder);
			}
			destroyBuilder();
			progressCaption='';
			dispatchEvent(new OrderBuildProgressEvent());
		}

	}
}