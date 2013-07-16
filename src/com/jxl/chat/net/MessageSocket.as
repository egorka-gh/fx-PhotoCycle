package com.jxl.chat.net
{
	import com.jxl.chat.events.MessageSocketEvent;
	import com.jxl.chat.factories.MessageFactory;
	import com.jxl.chat.vo.messages.ACKMessageVO;
	import com.jxl.chat.vo.messages.AbstractMessageVO;
	import com.jxl.chat.vo.messages.BuildMessageVO;
	import com.jxl.chat.vo.messages.ChatMessageVO;
	import com.jxl.chat.vo.messages.LoadMessageVO;
	import com.jxl.chat.vo.messages.MessageTypes;
	import com.jxl.chat.vo.messages.UnknownMessageVO;
	import com.photodispatcher.util.JsonUtil;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.Socket;
	
	import mx.collections.ArrayCollection;
	
	[Event(name="close", type="flash.events.Event")]
	[Event(name="connect", type="flash.events.Event")]
	[Event(name="ioError", type="flash.events.IOErrorEvent")]
	[Event(name="securityError", type="flash.events.SecurityErrorEvent")]
	[Event(name="socketData", type="flash.events.ProgressEvent")]
	[Event(name="newMessage", type="com.jxl.chat.events.MessageSocketEvent")]
	public class MessageSocket extends EventDispatcher{
		
		public static const MESSAGE_DELIMITER:String="~~~~~";
		
		private var _socket:Socket;
		private var _messages:ArrayCollection;
		
		public function get socket():Socket { return _socket; }
		
		public function get remoteIP():String {
			if(_socket && _socket.connected) return _socket.remoteAddress;
			return ''; 
		}
		
		public function get messages():ArrayCollection { return _messages; }
		public function get connected():Boolean
		{
			if(_socket)
			{
				return _socket.connected;
			}
			else
			{
				return false;
			}
		}
		
		public function MessageSocket(socket:Socket)
		{
			super();
			
			_socket = socket;
			_socket.addEventListener(Event.CLOSE,						onBubbleEvent);
			_socket.addEventListener(Event.CONNECT,						onBubbleEvent);
			_socket.addEventListener(IOErrorEvent.IO_ERROR,				onBubbleEvent);
			_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR,	onBubbleEvent);
			_socket.addEventListener(ProgressEvent.SOCKET_DATA, 		onData);
		}
		
		public function sendMessage(message:AbstractMessageVO):void
		{
			//DebugMax.log("MessageSocket::sendMessage: " + message);
			var json:String=message.toJSON();
			/*
			trace('-->');
			trace(json);
			*/
			_socket.writeUTFBytes(json+MESSAGE_DELIMITER);
			_socket.flush();
		}
		
		public function close():void
		{
			_socket.close();
		}
		
		public function connect(host:String, port:int):void
		{
			_socket.connect(host, port);
		}
		
		public function removeMessageAt(index:uint):void
		{
			messages.removeItemAt(index);
		}
		
		private function onBubbleEvent(event:Event):void
		{
			dispatchEvent(event);
		}
		
		private function onData(event:ProgressEvent):void
		{
			//DebugMax.logHeader();
			//DebugMax.log("MessageSocket::onData");
			if(_messages == null) _messages = new ArrayCollection();
			var latestMessages:Array = getMessagesFromSocket();
			var len:int = latestMessages.length;
			var messageSocketEvent:MessageSocketEvent;
			for(var index:uint = 0; index < len; index++)
			{
				var message:AbstractMessageVO = latestMessages[index];
				_messages.addItem(message);
				messageSocketEvent = new MessageSocketEvent(MessageSocketEvent.NEW_MESSAGE);
				messageSocketEvent.message = message;
				dispatchEvent(messageSocketEvent);
			}
		} 
		
		private var buffer:String='';
		public function getMessagesFromSocket():Array{
			var parsedMessages:Array = [];
			var message:AbstractMessageVO;
			var json:String						= _socket.readUTFBytes(socket.bytesAvailable);
			json=buffer+json;
			/*
			trace('<--');
			trace(json);
			*/
			var messageStrings:Array=json.split(MESSAGE_DELIMITER);
			buffer=messageStrings.pop(); //empty or not delemited part
			if(!buffer) buffer='';
			
			//messageStrings.length--; //remove last (empty) string
			var len:int = messageStrings.length;
			for(var index:uint = 0; index < len; index++){
				var messageStr:String = messageStrings[index];
				//var obj:Object = JSON.decode(messageStr);
				//var obj:Object = new JSONDecoder(messageStr).getValue();
				var obj:Object = JsonUtil.decode(messageStr);
				if(obj.t == undefined || (obj.t is String) == false){
					continue;
				}
				
				switch(obj.t){
					case MessageTypes.ABSTRACT:
						message = new AbstractMessageVO();
						break;
					
					case MessageTypes.ACK:
						message = new ACKMessageVO();
						break;
					
					case MessageTypes.CHAT:
						message = new ChatMessageVO();
						break;
					
					case MessageTypes.BUILD:
						message = new BuildMessageVO();
						break;
					case MessageTypes.LOAD:
						message = new LoadMessageVO()
						break;
					
					case MessageTypes.UNKNOWN:
						message = new UnknownMessageVO();
						break;
				}
				
				if(message){
					message.fromRaw(obj);
				}else{
					continue;
				}
				
				parsedMessages[index] = message;
			}
			
			return parsedMessages;
		}

	}
}