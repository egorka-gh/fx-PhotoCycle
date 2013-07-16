package com.jxl.chatserver.mvcs.models
{
	import com.jxl.chat.net.MessageSocket;
	import com.jxl.chat.vo.messages.AbstractMessageVO;
	import com.jxl.chatserver.vo.ClientVO;
	
	import flash.net.Socket;
	
	import mx.collections.ArrayCollection;
	
	public class ClientsModel{
		
		[Bindable]
		public var clients:ArrayCollection = new ArrayCollection();
		
		public function get length():int { return clients.length; }
		
		public function ClientsModel()
		{
		}
		
		public function hasClientMessageSocket(messageSocket:MessageSocket):Boolean
		{
			var len:int = clients.length;
			while(len--)
			{
				var clientVO:ClientVO = getClientAt(len);
				if(clientVO.messageSocket == messageSocket)
				{
					return true;
				}
			}
			return false;
		}
		
		public function hasUsername(username:String):Boolean
		{
			var userNameLocal:String = username.toLowerCase();
			var len:int = clients.length;
			while(len--)
			{
				var clientVO:ClientVO = getClientAt(len);
				if(clientVO.username.toLowerCase() == userNameLocal)
				{
					return true;
				}
			}
			return false;
		}
		
		public function addClient(messageSocket:MessageSocket, username:String=""):void{
			if(hasClientMessageSocket(messageSocket) == false){
				clients.addItem(new ClientVO(messageSocket, username));
			}else{
				trace("ChatServerService::addClient, client already added, yet you're adding them again.");
				//DebugMax.warn("ChatServerService::addClient, client already added, yet you're adding them again.");
			}
		}
		
		public function getClientBySocket(socket:Socket):ClientVO
		{
			var len:int = clients.length;
			while(len--)
			{
				var clientVO:ClientVO = getClientAt(len);
				if(clientVO.messageSocket.socket == socket)
				{
					return clientVO;
				}
			}
			return null;
		}
		
		public function getClientAt(index:uint):ClientVO
		{
			return clients.getItemAt(index) as ClientVO;
		}
		
		public function removeClientByMessageSocket(messageSocket:MessageSocket):void
		{
			var len:int = clients.length;
			while(len--)
			{
				var clientVO:ClientVO = getClientAt(len);
				if(clientVO.messageSocket == messageSocket)
				{
					clients.removeItemAt(len);
					return;
				}
			}
		}
		
		public function getClientUsernameList():Array
		{
			var usernames:Array = [];
			var len:int = clients.length;
			for(var index:uint = 0; index < len; index++)
			{
				var clientVO:ClientVO = getClientAt(index);
				usernames[index] = clientVO.username;
			}
			return usernames;
		}

	}
}