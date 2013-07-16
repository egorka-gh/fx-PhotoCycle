package com.jxl.chatserver.mvcs.controllers
{
	import com.jxl.chatserver.events.BootUserEvent;
	import com.jxl.chatserver.events.ChatServerEvent;
	import com.jxl.chatserver.events.ServiceEvent;
	import com.jxl.chatserver.mvcs.services.ChatServerService;
	import com.jxl.chatserver.views.ChatServerView3;

	public class ChatServerController
	{
		private var chatServerView:ChatServerView3;
		private var chatServerService:ChatServerService;
		
		public function ChatServerController(chatServerView:ChatServerView3)
		{
			super();
			
			this.chatServerView = chatServerView;
			
			chatServerView.addEventListener(ChatServerEvent.START_SERVER, 						onStartServer);
			chatServerView.addEventListener(BootUserEvent.BOOT,									onBootUser);
			chatServerView.addEventListener(ChatServerEvent.DISCONNECT,							onDisconnect);
			
			chatServerService = new ChatServerService();
			chatServerService.addEventListener(ServiceEvent.CHAT_SERVER_SERVICE_CONNECTED, 		onChatConnected);
			chatServerService.addEventListener(ServiceEvent.CHAT_SERVER_SERVICE_ERROR,			onChatServerError);
			
			chatServerView.connectedClients = chatServerService.clientsModel.clients;
		}
		
		public function destroy():void
		{
			chatServerView.connectedClients = null;
			chatServerService.close();
			
			chatServerView = null;
			chatServerService = null;
		}
		
		private function onStartServer(event:ChatServerEvent):void
		{
			chatServerService.startServer(event.host, event.port);
		}
		
		private function onBootUser(event:BootUserEvent):void
		{
			chatServerService.bootUser(event.user);
		}
		
		private function onChatServerError(event:ServiceEvent):void
		{
			chatServerView.failMessage 	= event.lastError;
			chatServerView.currentState = "fail_state";
		}
		
		private function onChatConnected(event:ServiceEvent):void
		{
			chatServerView.currentState = "ready_state";
		}
		
		private function onDisconnect(event:ChatServerEvent):void
		{
			chatServerService.close();
			chatServerView.currentState = "configure_state";
		}
	}
}