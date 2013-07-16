package com.jxl.chat.net
{
	import com.jxl.chat.events.PendingMessageEvent;
	import com.jxl.chat.vo.messages.ACKMessageVO;
	import com.jxl.chat.vo.messages.AbstractMessageVO;
	
	import mx.collections.ArrayCollection;
	
	public class MessageQueue
	{
		private static var ID_COUNTER:uint = 0;
		private var _id:uint;
		
		public function get id():uint { return _id; }
		
		private var messageSocket:MessageSocket;
		private var pendingMessages:ArrayCollection;
		private var currentPendingMessage:PendingMessage;
		
		public function MessageQueue(messageSocket:MessageSocket)
		{
			_id = ++ID_COUNTER;
			this.messageSocket = messageSocket;
		}
		
		public function addMessage(message:AbstractMessageVO):void
		{
			//DebugMax.debug("MessageQueue::addMessage, addMessage: " + message);
			if(pendingMessages == null) pendingMessages = new ArrayCollection();
			pendingMessages.addItem(new PendingMessage(messageSocket, message));
			processNextMessage();
		}
		
		public function sendACK(messageAcknowledging:AbstractMessageVO):void
		{
			var ackMessage:ACKMessageVO 				= new ACKMessageVO();
			ackMessage.ackMessageID						= messageAcknowledging.id;
			try
			{
				messageSocket.sendMessage(ackMessage);
			}
			catch(err:Error)
			{
				trace("MessageQueue::sendACK: " + err);
			}
		}
		
		public function destroy():void
		{
			if(pendingMessages == null) return;
			var len:int = pendingMessages.length;
			for(var index:uint = 0; index < len; index++)
			{
				PendingMessage(pendingMessages.getItemAt(index)).destroy();
			}
			pendingMessages.removeAll();
			if(currentPendingMessage)
			{
				currentPendingMessage.destroy();
				currentPendingMessage = null;
			}
		}
		
		private function processNextMessage():void
		{
			//DebugMax.logHeader();
			//DebugMax.log("MessageQueue::processNextMessage");
			if(currentPendingMessage == null && pendingMessages.length > 0)
			{
				//DebugMax.log("processing the latest message");
				currentPendingMessage = pendingMessages.removeItemAt(0) as PendingMessage;
				currentPendingMessage.addEventListener(PendingMessageEvent.ERROR, onPendingMessageError);
				currentPendingMessage.addEventListener(PendingMessageEvent.SUCCESS, onPendingMessageSuccess);
				currentPendingMessage.send();
			}
			else
			{
				if(currentPendingMessage)
				{
					//DebugMax.log("already processing a message");
				}
				else
				{
					//DebugMax.log("no more messages left to process");
				}
			}
		}
		
		private function destroyCurrentPendingMessage():void
		{
			if(currentPendingMessage)
			{
				currentPendingMessage.removeEventListener(PendingMessageEvent.ERROR, onPendingMessageError);
				currentPendingMessage.removeEventListener(PendingMessageEvent.SUCCESS, onPendingMessageSuccess);
				currentPendingMessage.destroy();
				currentPendingMessage = null;
			}
		}
		
		private function onPendingMessageError(event:PendingMessageEvent):void
		{
			//DebugMax.error("MessageManager::onPendingMessageError, failed getting an ack for message: " + currentPendingMessage.message);
			trace("MessageManager::onPendingMessageError, failed getting an ack for message: " + currentPendingMessage.message);
			destroyCurrentPendingMessage();
			processNextMessage();
		}
		
		private function onPendingMessageSuccess(event:PendingMessageEvent):void
		{
			//DebugMax.log("MessageQueue::onPendingMessageSuccess, id: " + id);
			destroyCurrentPendingMessage();
			processNextMessage();
		}

	}
}