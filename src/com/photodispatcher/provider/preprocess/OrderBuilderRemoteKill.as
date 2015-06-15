package com.photodispatcher.provider.preprocess{
	import com.jxl.chat.vo.ChatPretender;
	import com.jxl.chat.vo.InstructionConstants;
	import com.jxl.chat.vo.messages.BuildMessageVO;
	import com.jxl.chat.vo.messages.ChatMessageVO;
	import com.jxl.chat.vo.messages.MessageTypes;
	import com.jxl.chatserver.mvcs.services.ChatServerService;
	import com.jxl.chatserver.vo.ClientVO;
	import com.photodispatcher.model.mysql.entities.OrderState;
	import com.photodispatcher.model.mysql.entities.StateLog;

	public class OrderBuilderRemoteKill extends OrderBuilderBase{
		
		public var client:ClientVO;
		
		public function OrderBuilderRemoteKill(client:ClientVO){
			super();
			type=OrderBuilderBase.TYPE_REMOTE;
			this.client=client;
			this.logStates=true;
		}
		
		override protected function startBuild():void{
			if((!lastOrder.printGroups || lastOrder.printGroups.length==0) && (!lastOrder.suborders || lastOrder.suborders.length==0)){	
				if(logStates) StateLog.log(lastOrder.state,lastOrder.id,'','Пустой заказ. Не требует подготовки');
				releaseComplite();
				return;
			}
			lastOrder.state=OrderState.PREPROCESS_DEPLOY;
			var msg:BuildMessageVO=new BuildMessageVO();
			msg.instructions=InstructionConstants.SERVER_BUILD_POST;
			//msg.message='Размещение на подготовку заказа '+lastOrder.id;
			msg.message=ChatPretender.buildPostMessage()+lastOrder.id;
			msg.order=lastOrder;
			ChatServerService.instance.sendDirectMessage(client,msg);
			if(logStates) StateLog.log(lastOrder.state,lastOrder.id,'',client.username);
		}
		
		public function processMessage(message:ChatMessageVO):void{
			var msg:BuildMessageVO;
			if(message.type==MessageTypes.BUILD) msg=message as BuildMessageVO;
			if(!msg) return;
			switch(msg.instructions){
				case InstructionConstants.CLIENT_BUILD_CONFIRM:
					lastOrder.state=OrderState.PREPROCESS_REMOTE;
					if(logStates) StateLog.log(lastOrder.state,lastOrder.id,'',client.username);
					break;
				case InstructionConstants.CLIENT_BUILD_REJECT:
					skipOnReject=true;
					builderError(msg.message);
					break;
				case InstructionConstants.CLIENT_BUILD_COMPLETE:
					lastOrder.state=msg.order.state;
					lastOrder.printGroups=msg.order.printGroups;
					lastOrder.suborders=msg.order.suborders;
					if(msg.hasError){
						releaseWithError(lastOrder.state,msg.errorMsg);
					}else{
						releaseComplite();
					}
					/*
					//4 debug
					ChatServerService.instance.broadcastMessage('msg.hasError='+msg.hasError);
					*/
					break;
			}
		}
	}
}