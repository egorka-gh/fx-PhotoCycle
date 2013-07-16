package com.jxl.chatserver.mvcs.services{
	import com.jxl.chat.events.MessageSocketEvent;
	import com.jxl.chat.net.MessageManager;
	import com.jxl.chat.net.MessageSocket;
	import com.jxl.chat.vo.InstructionConstants;
	import com.jxl.chat.vo.messages.AbstractMessageVO;
	import com.jxl.chat.vo.messages.ChatMessageVO;
	import com.jxl.chatserver.events.ServiceEvent;
	import com.jxl.chatserver.mvcs.models.ClientsModel;
	import com.jxl.chatserver.vo.ClientVO;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.net.ServerSocket;
	import flash.net.Socket;

	[Event(name="chatServerServiceConnected", type="com.jxl.chatserver.events.ServiceEvent")]
	[Event(name="chatServerServiceError", type="com.jxl.chatserver.events.ServiceEvent")]
	[Event(name="chatServerServiceDisconnected", type="com.jxl.chatserver.events.ServiceEvent")]
	[Event(name="chatServerServiceUserOnline", type="com.jxl.chatserver.events.ServiceEvent")]
	[Event(name="chatServerServiceUserOffline", type="com.jxl.chatserver.events.ServiceEvent")]
	[Event(name="chatServerServiceUserMessage", type="com.jxl.chatserver.events.ServiceEvent")]
	public class ChatServerService extends EventDispatcher{
		private static const WHATS_MY_NAME_BEEEEOOOTCH:String = "Server";

		protected static var _instance:ChatServerService;
		public static function get instance():ChatServerService{
			if(!_instance) _instance = new ChatServerService();
			return _instance;
		}
		
		[Bindable]
		public var isOnline:Boolean=false;
		
		private var socket:ServerSocket;
		private var _clientsModel:ClientsModel = new ClientsModel();
		private var messageManager:MessageManager = MessageManager.instance;
		
		public function get clientsModel():ClientsModel { return _clientsModel; }
		
		public function ChatServerService(){
			super();
			if (ChatServerService._instance){
				throw new Error('Singleton error');
			}else{
				ChatServerService._instance=this;
			}
		}
		
		public function startServer(host:String='127.0.0.1', port:int=8087):void{
			//DebugMax.log("ChatServerService::startServer, host: " + host + ", port: " + port);
			destroy();
			
			createSocket();
			
			try
			{
				socket.bind(port, host);
				socket.listen();
			}
			catch(err:Error){
				//DebugMax.error("ChatServerService::connect, err: " + err);
				trace("ChatServerService::connect, err: " + err);
				dispatchError(err.message);
				return;
			}
			isOnline=true;
			dispatchEvent(new ServiceEvent(ServiceEvent.CHAT_SERVER_SERVICE_CONNECTED));
		}
		
		private function destroySocket():void{
			if(socket){
				socket.removeEventListener(Event.CONNECT, 							onClientSocketConnected);
				socket.removeEventListener(Event.CLOSE,								onClose);
				socket = null;
			}
		}
		
		private function createSocket():void
		{
			destroy();
			socket = new ServerSocket();
			socket.addEventListener(Event.CONNECT, 								onClientSocketConnected);
			socket.addEventListener(Event.CLOSE,								onClose);
		}
		
		private function onClose(event:Event):void{
			isOnline=false;
			dispatchEvent(new ServiceEvent(ServiceEvent.CHAT_SERVER_SERVICE_DISCONNECTED));
			//DebugMax.log("ChatServerService::onClose");
		}
		
		private function onClientSocketConnected(event:ServerSocketConnectEvent):void
		{
            var clientSocket:Socket 		= event.socket as Socket;
         	var messageSocket:MessageSocket = new MessageSocket(clientSocket);
         	
         	clientsModel.addClient(messageSocket);
         	
         	messageSocket.addEventListener(MessageSocketEvent.NEW_MESSAGE,		onClientNewMessage);
            messageSocket.addEventListener(Event.CLOSE, 						onClientSocketClose); 
            messageSocket.addEventListener(IOErrorEvent.IO_ERROR, 				onClientError);
            messageSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, 	onClientError);
             
            //Send a client connect message 
            //sendMessageToClient(messageSocket, InstructionConstants.SERVER_CLIENT_CONNECTED, "Connected to server.", WHATS_MY_NAME_BEEEEOOOTCH);
			sendMessageToClient(messageSocket, InstructionConstants.SERVER_CLIENT_CONNECTED, messageSocket.remoteIP, WHATS_MY_NAME_BEEEEOOOTCH);
		}
		
		private function dispatchError(message:String):void{
			var errorEvent:ServiceEvent = new ServiceEvent(ServiceEvent.CHAT_SERVER_SERVICE_ERROR);
			errorEvent.lastError = message;
			dispatchEvent(errorEvent);
		}
				
		private function sendMessageToClient(messageSocket:MessageSocket, instructions:String, message:*, username:String):void{
			//DebugMax.log("ChatServerService::sendMessageToClient, " + username + "> " + instructions + ", " + message);
			var chatMessage:ChatMessageVO			= new ChatMessageVO();
			chatMessage.instructions				= instructions;
			chatMessage.message						= message;
			chatMessage.username					= username;
			
			messageManager.addMessage(messageSocket, chatMessage);
			/*
			try
			{
				clientSocket.writeUTFBytes(chatMessage.toJSON()); 
            	clientSocket.flush();
   			}
   			catch(err:Error)
   			{
   				DebugMax.error("ChatServerService::sendMessageToClient, err: " + err);
   			}
   			*/
		}
		
		public function sendDirectMessage(client:ClientVO, message:ChatMessageVO):void{
			if(!client || !message) return;
			message.username = WHATS_MY_NAME_BEEEEOOOTCH;
			messageManager.addMessage(client.messageSocket, message);
			var evt:ServiceEvent=new ServiceEvent(ServiceEvent.CHAT_SERVER_SERVICE_SERVER_MESSAGE);
			evt.user=client;
			evt.message=message;
			dispatchEvent(evt);
		}
		
		public function setUserTypeRequest(client:ClientVO, newType:int):void{
			if(!client || client.userType==newType) return;
			var chatMessage:ChatMessageVO= new ChatMessageVO();
			chatMessage.instructions=InstructionConstants.SERVER_SET_USERTYPE;
			chatMessage.message=client.username+ ': Давайка ты будешь ' + ClientVO.modeName(newType);
			chatMessage.userType=newType;
			sendDirectMessage(client,chatMessage);
		}
		
		private function sendGlobalChatMessage(instructions:String, message:String, username:String):void
		{
			//DebugMax.log("ChatServerService::sendGlobalChatMessage, " + username + "> " + instructions + ", " + message);
			var len:int = clientsModel.length;
			while(len--)
			{
				var clientSocketVO:ClientVO = clientsModel.getClientAt(len);
				sendMessageToClient(clientSocketVO.messageSocket, instructions, message, username);
			}
		}
		
		public function broadcastMessage(message:String):void{
			if(!message) return;
			var msg:ChatMessageVO= new ChatMessageVO;
			msg.username=WHATS_MY_NAME_BEEEEOOOTCH;
			msg.instructions=InstructionConstants.SERVER_CLIENT_CHAT_MESSAGE;
			msg.message=message;
			var len:int = clientsModel.length;
			while(len--){
				var clientSocketVO:ClientVO = clientsModel.getClientAt(len);
				sendMessageToClient(clientSocketVO.messageSocket, msg.instructions, message, msg.username);
			}
			var evt:ServiceEvent=new ServiceEvent(ServiceEvent.CHAT_SERVER_SERVICE_SERVER_MESSAGE);
			evt.user=null;
			evt.message=msg;
			dispatchEvent(evt);
		}
		
		public function getClientsByType(type:int=-1):Array{
			var result:Array=[];
			var len:int = clientsModel.length;
			while(len--){
				var clientVO:ClientVO = clientsModel.getClientAt(len);
				if(clientVO && (type==-1 || clientVO.userType==type)) result.push(clientVO);
			}
			return result;
		}
		
		private function destroyClients():void
		{
			var len:int = clientsModel.length;
            while(len--)
            {
            	var clientSocketVO:ClientVO = clientsModel.getClientAt(len);
				var evt:ServiceEvent=new ServiceEvent(ServiceEvent.CHAT_SERVER_SERVICE_USER_OFFLINE);
				evt.user=clientSocketVO;
				dispatchEvent(evt);
            	destroyClient(clientSocketVO.messageSocket);
            }
		}
		
		private function destroyClient(messageSocket:MessageSocket):void{
			messageManager.clearQueue(messageSocket);
			clientsModel.removeClientByMessageSocket(messageSocket);
			removeClientListeners(messageSocket);
            try{
            	messageSocket.close();
            }catch(err:Error){}
		}
		
		private function removeClientListeners(messageSocket:MessageSocket):void
		{
			messageSocket.removeEventListener(MessageSocketEvent.NEW_MESSAGE,		onClientNewMessage); 
            messageSocket.removeEventListener(Event.CLOSE, 							onClientSocketClose); 
            messageSocket.removeEventListener(IOErrorEvent.IO_ERROR, 				onClientError);
            messageSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, 	onClientError);
		}
		
		public function destroy():void{
			isOnline=false;
			destroyClients();
			destroySocket();
			messageManager.destroy();
		}
		
		// -- Client Handlers --
		private function onClientNewMessage(event:MessageSocketEvent):void
		{
			//DebugMax.log("ChatServerService::onClientNewMessage");
			
			var messageSocket:MessageSocket 		= event.target as MessageSocket;
			var clientVO:ClientVO					= clientsModel.getClientBySocket(messageSocket.socket);
			var len:int 							= messageSocket.messages.length;
			for(var index:uint = 0; index < len; index++)
			{
				var message:AbstractMessageVO = messageSocket.messages.getItemAt(index) as AbstractMessageVO;
				if(message is ChatMessageVO)
	            {
	            	var chatMessage:ChatMessageVO = message as ChatMessageVO;
	            	if(chatMessage == null)
	            	{
	            		//DebugMax.warn("ChatServerService::onClientNewMessage, couldn't parse chat message.");
						trace("ChatServerService::onClientNewMessage, couldn't parse chat message.");
	            		return;
	            	}
	            }
	            else
	            {
	            	// we only care about chat messages, we ignore everything else including ACK's
	            	continue;
	            }
	 			
	 			messageSocket.removeMessageAt(index);
	 			index--;
	 			len--;
	 			messageManager.sendACK(messageSocket, chatMessage);
				var evt:ServiceEvent;
	 			switch(chatMessage.instructions){
	 				case InstructionConstants.CLIENT_SET_USERNAME:
						clientVO.username = chatMessage.username;
						clientVO.userType= chatMessage.userType;
	 					clientsModel.clients.setItemAt(clientVO, clientsModel.clients.getItemIndex(clientVO));
	 					sendGlobalChatMessage(InstructionConstants.SERVER_CLIENT_CONNECTED_TO_CHAT, chatMessage.username + " connected to the chat.", chatMessage.username);
	 					var usernameList:Array = clientsModel.getClientUsernameList();
	 					sendMessageToClient(clientVO.messageSocket, InstructionConstants.SERVER_UPDATED_USER_LIST, usernameList, WHATS_MY_NAME_BEEEEOOOTCH);
						evt=new ServiceEvent(ServiceEvent.CHAT_SERVER_SERVICE_USER_ONLINE);
						evt.user=clientVO;
	 					break;
	 				case InstructionConstants.CLIENT_CHAT_MESSAGE:
	 					// echo chat messages to all in group
	 					sendGlobalChatMessage(InstructionConstants.SERVER_CLIENT_CHAT_MESSAGE, chatMessage.message, chatMessage.username);
						evt=new ServiceEvent(ServiceEvent.CHAT_SERVER_SERVICE_USER_MESSAGE);
						evt.user=clientVO;
						evt.message=chatMessage;
	 					break;
					case InstructionConstants.CLIENT_SET_USERTYPE:
						clientVO.userType=chatMessage.userType;
					case InstructionConstants.CLIENT_BUILD_CONFIRM:
					case InstructionConstants.CLIENT_BUILD_COMPLETE:
					case InstructionConstants.CLIENT_BUILD_REJECT:
					case InstructionConstants.CLIENT_LOAD_CONFIRM:
					case InstructionConstants.CLIENT_LOAD_COMPLETE:
					case InstructionConstants.CLIENT_LOAD_REJECT:
						// echo messages to client 
						sendMessageToClient(clientVO.messageSocket, InstructionConstants.SERVER_CLIENT_CHAT_MESSAGE, chatMessage.message, chatMessage.username);
					case InstructionConstants.CLIENT_LOAD_PROGRESS:
						//generate event
						evt=new ServiceEvent(ServiceEvent.CHAT_SERVER_SERVICE_USER_MESSAGE);
						evt.user=clientVO;
						evt.message=chatMessage;
						break;
	 				default:
	 					// ignore rogue messages
	 					//sendGlobalChatMessage(InstructionConstants.SERVER_UKNOWN_CLIENT_MESSAGE, "lol, wut? DoEs n0T cOmPUt3, OT OT OT", WHATS_MY_NAME_BEEEEOOOTCH);
	 			}
				if(evt) dispatchEvent(evt);
			}
		}
		
		private function onClientSocketClose(event:Event):void
		{
			var clientSocket:MessageSocket			= event.target as MessageSocket;
			var clientVO:ClientVO 					= clientsModel.getClientBySocket(clientSocket.socket);
			if(clientVO)
			{
				sendGlobalChatMessage(InstructionConstants.SERVER_CLIENT_DISCONNECTED, clientVO.username, WHATS_MY_NAME_BEEEEOOOTCH);
			}
			var evt:ServiceEvent=new ServiceEvent(ServiceEvent.CHAT_SERVER_SERVICE_USER_OFFLINE);
			evt.user=clientVO;
			dispatchEvent(evt);

			destroyClient(clientSocket);
		}
		
		private function onClientError(event:ErrorEvent):void{
			//DebugMax.error("ChatServerService::onClientError: " + event.text);
			trace("ChatServerService::onClientError: " + event.text);
		}
		
		public function bootUser(user:ClientVO):void
		{
			destroyClient(user.messageSocket);
			sendGlobalChatMessage(InstructionConstants.SERVER_USER_BOOTED, user.username + " was booted from the chat.", WHATS_MY_NAME_BEEEEOOOTCH);
			var evt:ServiceEvent=new ServiceEvent(ServiceEvent.CHAT_SERVER_SERVICE_USER_OFFLINE);
			evt.user=user;
			dispatchEvent(evt);
		}
		
		public function close():void{
			if(socket && socket.listening){
				socket.close();
				dispatchEvent(new ServiceEvent(ServiceEvent.CHAT_SERVER_SERVICE_DISCONNECTED));
			}
			destroy();
		}
	}
}