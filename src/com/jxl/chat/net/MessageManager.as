package com.jxl.chat.net
{
	import com.jxl.chat.vo.messages.AbstractMessageVO;
	
	import flash.utils.Dictionary;
	
	public class MessageManager
	{
		
		private static var _inst:MessageManager;
		
		public static function get instance():MessageManager
		{
			if(_inst == null) _inst = new MessageManager();
			return _inst;
		}
		
		private var queues:Dictionary = new Dictionary();
		
		public function MessageManager()
		{
		}
		
		public function addMessage(messageSocket:MessageSocket, message:AbstractMessageVO):void
		{
			//DebugMax.debug("MessageManager::addMessage, message: " + message);
			if(queues[messageSocket] == null)
				queues[messageSocket] = new MessageQueue(messageSocket);
			
			MessageQueue(queues[messageSocket]).addMessage(message);
		}

		public function clearQueue(messageSocket:MessageSocket):void{
			var queue:MessageQueue=queues[messageSocket] as MessageQueue;
			if(!queue) return;
			queue.destroy();
			delete queues[messageSocket];
		}

		public function sendACK(messageSocket:MessageSocket, messageAcknowledging:AbstractMessageVO):void
		{
			if(queues[messageSocket] == null)
				queues[messageSocket] = new MessageQueue(messageSocket);
			
			MessageQueue(queues[messageSocket]).sendACK(messageAcknowledging);
		}
		
		public function destroy():void
		{
			for(var queue:* in queues)
			{
				MessageQueue(queues[queue]).destroy();
			}
		}

	}
}