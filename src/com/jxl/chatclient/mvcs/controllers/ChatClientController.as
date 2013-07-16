package com.jxl.chatclient.mvcs.controllers
{
	import com.jxl.chat.vo.InstructionConstants;
	import com.jxl.chat.vo.messages.ChatMessageVO;
	import com.jxl.chatclient.ChatClientWindow;
	import com.jxl.chatclient.events.ChatEvent;
	import com.jxl.chatclient.events.LoginEvent;
	import com.jxl.chatclient.events.ServiceEvent;
	import com.jxl.chatclient.mvcs.services.ChatService;
	import com.jxl.chatskins.events.ConnectingAnimeEvent;
	
	import flash.events.Event;
	
	import mx.collections.ArrayCollection;
	
	public class ChatClientController
	{
		private var chatClient:ChatClientWindow;
		private var chatService:ChatService;
		private var host:String;
		private var port:uint;
		private var username:String;
		
		public function ChatClientController(chatClient:ChatClientWindow)
		{
			this.chatClient = chatClient;
			this.chatClient.addEventListener(LoginEvent.LOGIN, 						onLogin);
			this.chatClient.addEventListener(ChatEvent.CHAT_MESSAGE, 				onSendChatMessage);
			this.chatClient.addEventListener(ConnectingAnimeEvent.READY,			onConnectingAnimeReady);
			this.chatClient.addEventListener(ConnectingAnimeEvent.COMPLETE, 		onConnectingAnimeCompleted);
			this.chatClient.addEventListener(Event.CLOSING,							onClosing);
			this.chatClient.addEventListener(ChatEvent.DISCONNECT,					onDisconnect);
			
			chatService = new ChatService();
			chatService.addEventListener(ServiceEvent.CHAT_MESSAGE, 			onChatMessage);
			chatService.addEventListener(ServiceEvent.CONNECTED, 				onChatConnected);
			chatService.addEventListener(ServiceEvent.DISCONNECTED, 			onChatDisconnected);
			chatService.addEventListener(ServiceEvent.ERROR, 					onChatError);
			chatService.addEventListener(ServiceEvent.JOINED_CHAT, 				onJoinedChat);
			chatService.addEventListener(ServiceEvent.USER_LIST_UPDATED, 		onUserListUpdated);
			chatService.addEventListener(ServiceEvent.USERNAME_TAKEN, 			onUsernameTaken);
			chatService.addEventListener(ServiceEvent.USER_JOINED_CHAT,			onUserJoinedChat);
			chatService.addEventListener(ServiceEvent.USER_LEFT_CHAT,			onUserLeftChat);
		}
		
		private function onLogin(event:LoginEvent):void
		{
			//DebugMax.info("ChatClientController::onLogin");
			host 			= event.host;
			port 			= event.port;
			username 		= event.username;
			chatClient.showConnectingState();
		}
		
		private function onDisconnect(event:ChatEvent):void
		{
			chatService.destroySocket();
			chatClient.currentState = "configure_state";
		}
		
		private function onSendChatMessage(event:ChatEvent):void
		{
			chatService.sendChatMessage(InstructionConstants.CLIENT_CHAT_MESSAGE, event.message);
		}
		
		private function onUsernameTaken(event:ServiceEvent):void
		{
			chatClient.usernameTaken();
		}
		
		private function onChatMessage(event:ServiceEvent):void
		{
			chatClient.addChatMessage(event.chatMessage);
		}
		
		private function onChatConnected(event:ServiceEvent):void
		{
			// kruft
		}
		
		private function onConnectingAnimeReady(event:ConnectingAnimeEvent):void
		{
			//DebugMax.info("ChatClientController::onConnectingAnimeReady");
			chatService.connect(host, port, username);
		}
		
		private function onConnectingAnimeCompleted(event:ConnectingAnimeEvent):void
		{
			//DebugMax.info("ChatClientController::onConnectingAnimeCompleted: " + event);
			chatClient.currentState = "chat_state";
		}
		
		private function onChatDisconnected(event:ServiceEvent):void
		{
			chatClient.currentState = "configure_state";
		}
		
		private function onChatError(event:ServiceEvent):void
		{
			chatClient.currentState = "fail_state";
			chatClient.failMessage = event.lastError;
		}
		
		private function onJoinedChat(event:ServiceEvent):void
		{
			//DebugMax.info("ChatClientController::onJoinedChat");
			
			chatClient.showConnected();
		}
		
		private function onUserListUpdated(event:ServiceEvent):void
		{
			//DebugMax.log("ChatClientController::onUserListUpdated");
			chatClient.users = new ArrayCollection(event.userList);
		}
		
		private function onUserJoinedChat(event:ServiceEvent):void
		{
			//DebugMax.log("ChatClientController::onUserJoinedChat");
			chatClient.users.addItem(event.chatMessage.username);
			chatClient.addServerMessage(event.chatMessage.username + " joined.");
		}
		
		private function onUserLeftChat(event:ServiceEvent):void
		{
			//DebugMax.log("ChatClientController::onUserLeftChat, message: " + event.chatMessage);
			try
			{
				//DebugMax.log("message: " + message);
				var index:int = chatClient.users.getItemIndex(event.chatMessage.message);
				//DebugMax.log("index: " + index);
				chatClient.users.removeItemAt(index);
			}
			catch(err:Error)
			{
				DebugMax.error("ChatClientController::onUserLeftChat: " + err);
			}
			
			chatClient.addServerMessage(event.chatMessage.message + " has left.");
		}
		
		private function onClosing(event:Event):void
		{
			destroy();
		}
		
		private function destroy():void
		{
			chatClient.removeEventListener(LoginEvent.LOGIN, 						onLogin);
			chatClient.removeEventListener(ChatEvent.CHAT_MESSAGE, 					onSendChatMessage);
			chatClient.removeEventListener(ConnectingAnimeEvent.READY,				onConnectingAnimeReady);
			chatClient.removeEventListener(ConnectingAnimeEvent.COMPLETE, 			onConnectingAnimeCompleted);
			chatClient.removeEventListener(Event.CLOSING,							onClosing);
			chatClient = null;
			
			chatService.removeEventListener(ServiceEvent.CHAT_MESSAGE, 				onChatMessage);
			chatService.removeEventListener(ServiceEvent.CONNECTED, 				onChatConnected);
			chatService.removeEventListener(ServiceEvent.DISCONNECTED, 				onChatDisconnected);
			chatService.removeEventListener(ServiceEvent.ERROR, 					onChatError);
			chatService.removeEventListener(ServiceEvent.JOINED_CHAT, 				onJoinedChat);
			chatService.removeEventListener(ServiceEvent.USER_LIST_UPDATED, 		onUserListUpdated);
			chatService.removeEventListener(ServiceEvent.USERNAME_TAKEN, 			onUsernameTaken);
			chatService.removeEventListener(ServiceEvent.USER_JOINED_CHAT,			onUserJoinedChat);
			chatService.removeEventListener(ServiceEvent.USER_LEFT_CHAT,			onUserLeftChat);
			chatService.destroySocket();
			chatService = null;
		}
		
		
		
		

	}
}