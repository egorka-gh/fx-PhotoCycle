package com.jxl.chat.net
{
	import com.jxl.chat.events.MessageSocketEvent;
	import com.jxl.chat.events.PendingMessageEvent;
	import com.jxl.chat.vo.messages.ACKMessageVO;
	import com.jxl.chat.vo.messages.AbstractMessageVO;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	[Event(name="success", type="com.jxl.chat.events.PendingMessageEvent")]
	[Event(name="error", type="com.jxl.chat.events.PendingMessageEvent")]
	public class PendingMessage extends EventDispatcher
	{
		private static const MAX_RETRIES:uint 		= 3;
		private static var ID_COUNTER:uint 			= 0;
		
		private var _id:uint;
		
		public function get id():uint { return _id; }
		
		
		private var _messageSocket:MessageSocket;
		private var _message:AbstractMessageVO;
		private var currentRetry:uint = 0;
		private var retryTimer:Timer;
		
		public function get messageSocket():MessageSocket { return _messageSocket; }
		public function get message():AbstractMessageVO { return _message; }
		
		public function PendingMessage(messageSocket:MessageSocket, message:AbstractMessageVO):void
		{
			_messageSocket 	= messageSocket;
			_messageSocket.addEventListener(IOErrorEvent.IO_ERROR, onError);
			_messageSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
			_messageSocket.addEventListener(Event.CLOSE, onClose);
			_messageSocket.addEventListener(MessageSocketEvent.NEW_MESSAGE, onNewMessage);
			
			_message	 	= message;
		}
		
		public function send():void
		{
			//DebugMax.log("PendingMessage::send, message: " + _message);
			try
			{
				_messageSocket.sendMessage(_message);
			}
			catch(err:Error)
			{
				//DebugMax.error("SocketMessage::send, err: " + err);
				trace("SocketMessage::send, err: " + err);
				if(err.errorID != 2002)
				{
					retry();
				}
				else
				{
					removeSocketListeners();
					dispatchEvent(new PendingMessageEvent(PendingMessageEvent.ERROR));
				}
			}
		}
		
		public function destroy():void
		{
			//DebugMax.info("PendingMessage::destroy, id: " + id);
			removeSocketListeners();
			_messageSocket 		= null;
			_message	 		= null;
			currentRetry 		= 0;
			if(retryTimer)
			{
				retryTimer.removeEventListener(TimerEvent.TIMER, onTick);
				retryTimer.stop();
				retryTimer = null;
			}
		}
		
		private function onClose(event:Event):void
		{
			//DebugMax.error("PendingMessage::onClose, id: " + id);
			removeSocketListeners();
			dispatchEvent(new PendingMessageEvent(PendingMessageEvent.ERROR));
		}
		
		private function onError(event:ErrorEvent):void
		{
			//DebugMax.error("PendingMessage::onError: " + event.text);
			trace("PendingMessage::onError: " + event.text);
			removeSocketListeners();
			dispatchEvent(new PendingMessageEvent(PendingMessageEvent.ERROR));
		}
		
		private function onNewMessage(event:MessageSocketEvent):void
		{
			//DebugMax.log("PendingMessage::onNewMessage");
			var len:int = messageSocket.messages.length;
			for(var index:uint = 0; index < len; index++)
			{
				var message:AbstractMessageVO = messageSocket.messages.getItemAt(index) as AbstractMessageVO;
				if(message is ACKMessageVO && ACKMessageVO(message).ackMessageID == _message.id)
				{
					
					messageSocket.removeMessageAt(index);
					index--;
					len--;
					removeSocketListeners();
					dispatchEvent(new PendingMessageEvent(PendingMessageEvent.SUCCESS));
					return;
				}
			}
		}
		
		private function removeSocketListeners():void
		{
			if(_messageSocket)
			{
				_messageSocket.removeEventListener(IOErrorEvent.IO_ERROR, onError);
				_messageSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
				_messageSocket.removeEventListener(Event.CLOSE, onClose);
				_messageSocket.removeEventListener(MessageSocketEvent.NEW_MESSAGE, onNewMessage);
			}
		}
		
		private function retry():void
		{
			//DebugMax.log("PendingMessage::retry: " + currentRetry);
			if(currentRetry + 1 < MAX_RETRIES)
			{
				currentRetry++;
				if(retryTimer == null)
				{
					retryTimer = new Timer(1000, 1);
					retryTimer.addEventListener(TimerEvent.TIMER, onTick, false, 0, true);
				}
				retryTimer.reset();
				retryTimer.start();
			}
			else
			{
				removeSocketListeners();
				dispatchEvent(new PendingMessageEvent(PendingMessageEvent.ERROR));
			}
		}
		
		private function onTick(event:TimerEvent):void
		{
			retryTimer.stop();
			send();
		}
		
		

	}
}