package com.photodispatcher.provider.ftp{
	import com.jxl.chat.vo.ChatPretender;
	import com.jxl.chat.vo.InstructionConstants;
	import com.jxl.chat.vo.messages.ChatMessageVO;
	import com.jxl.chat.vo.messages.LoadMessageVO;
	import com.jxl.chat.vo.messages.MessageTypes;
	import com.jxl.chatserver.mvcs.services.ChatServerService;
	import com.jxl.chatserver.vo.ClientVO;
	import com.photodispatcher.event.ImageProviderEvent;
	import com.photodispatcher.model.mysql.entities.Order;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.dao.StateLogDAO;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	[Event(name="orderLoaded", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="flowError", type="com.photodispatcher.event.ImageProviderEvent")]
	[Event(name="loadFault", type="com.photodispatcher.event.ImageProviderEvent")] 
	[Event(name="change", type="flash.events.Event")]
	public class LoadHelper extends EventDispatcher{
		
		public var client:ClientVO;

		public var lastError:int=0;
		public var lastErrMsg:String='';
		public var lastUsageDate:Date;
		public var skipOnReject:Boolean=false;

		public var filesTotal:int=0;
		public var filesDone:int=0;
		public var speed:Number=0;

		private var _order:Order;
		public function get currentOrder():Order{
			return _order;
		}

		private var _isBusy:Boolean=false; 
		public function get isBusy():Boolean{
			return _isBusy;
		}

		public function LoadHelper(client:ClientVO){
			super(null);
			this.client=client;
			lastUsageDate=new Date();
			lastUsageDate.fullYear=lastUsageDate.fullYear-1;
		}
		
		public function processMessage(message:ChatMessageVO):void{
			//TODO implement
			var msg:LoadMessageVO;
			if(message.type==MessageTypes.LOAD) msg=message as LoadMessageVO;
			if(!msg) return;
			
			switch(msg.instructions){
				case InstructionConstants.CLIENT_LOAD_CONFIRM:
					_order.state=OrderState.FTP_REMOTE;
					StateLogDAO.logState(_order.state,_order.id,'',client.username);
					break;
				case InstructionConstants.CLIENT_LOAD_REJECT:
					if(!msg.hasError) skipOnReject=true; //is busy or some else, skip me next time 
					if(msg.order){
						_order.state=msg.order.state;
					}
					//reset();
					flowError(msg.message);
					break;
				case InstructionConstants.CLIENT_LOAD_PROGRESS:
					filesTotal=msg.filesTotal;
					filesDone=msg.filesDone;
					speed=msg.speed;
					dispatchEvent(new Event(Event.CHANGE));
					break;
				case InstructionConstants.CLIENT_LOAD_COMPLETE:
					_order.state=msg.order.state;
					_order.printGroups=msg.order.printGroups;
					_order.suborders=msg.order.suborders;
					
					StateLogDAO.logState(_order.state,_order.id,'',msg.errorMsg);
					lastUsageDate= new Date();
					var order:Order=currentOrder;
					//reset();
					if(msg.hasError){
						dispatchEvent(new ImageProviderEvent(ImageProviderEvent.LOAD_FAULT_EVENT,order,msg.errorMsg));
					}else{
						dispatchEvent(new ImageProviderEvent(ImageProviderEvent.ORDER_LOADED_EVENT,order));
					}
					break;
			}

		}
		
		public function reset():void{
			_isBusy=false;
			_order=null;
			lastError=0;
			lastErrMsg='';
			filesTotal=0;
			filesDone=0;
			speed=0;
		}
		
		public function post(order:Order):void{
			if(!order) return;
			_order=order;
			if(isBusy){
				flowError("can't post (busy)");
				return;
			}
			_isBusy=true;
			_order.state=OrderState.FTP_DEPLOY;
			var msg:LoadMessageVO=new LoadMessageVO();
			msg.instructions=InstructionConstants.SERVER_LOAD_POST;
			msg.message=ChatPretender.loadPostMessage()+_order.id;
			msg.order=_order;
			StateLogDAO.logState(_order.state,_order.id,'',client.username);
			ChatServerService.instance.sendDirectMessage(client,msg);
		}
		
		public function stop():void{
			if(!isBusy) return;
			var msg:LoadMessageVO=new LoadMessageVO();
			msg.instructions=InstructionConstants.SERVER_LOAD_STOP;
			msg.message='Остановить загрузку заказа '+currentOrder.id;
			ChatServerService.instance.sendDirectMessage(client,msg);
		}

		private function flowError(errMsg:String):void{
			dispatchEvent(new ImageProviderEvent(ImageProviderEvent.FLOW_ERROR_EVENT,null,errMsg));
		}


	}
}