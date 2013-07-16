package com.jxl.chat.factories
{
	import com.jxl.chat.vo.messages.ACKMessageVO;
	import com.jxl.chat.vo.messages.AbstractMessageVO;
	import com.jxl.chat.vo.messages.BuildMessageVO;
	import com.jxl.chat.vo.messages.ChatMessageVO;
	import com.jxl.chat.vo.messages.LoadMessageVO;
	import com.jxl.chat.vo.messages.MessageTypes;
	import com.jxl.chat.vo.messages.UnknownMessageVO;
	import com.photodispatcher.util.JsonUtil;
	
	import flash.net.Socket;
	
	public class MessageFactory{
		//TODO unused - kill
		public static const MESSAGE_DELIMITER:String="~~~~~";

		public static function getMessagesFromSocket(socket:Socket):Array{
			var json:String						= socket.readUTFBytes(socket.bytesAvailable);
			/*
			trace('<--');
			trace(json);
			*/
			//DebugMax.log("MessageFactory::getMessagesFromSocket");
			//DebugMax.log("-- json --");
			//DebugMax.log(json);
			//var messageStrings:Array			= json.split("}");
			var messageStrings:Array			= json.split(MESSAGE_DELIMITER);
			messageStrings.length--; //remove last (empty) string
			var len:int = messageStrings.length;
			var parsedMessages:Array = [];
			var message:AbstractMessageVO;
			for(var index:uint = 0; index < len; index++)
			{
				var messageStr:String = messageStrings[index];
				//var obj:Object = JSON.decode(messageStr);
				//var obj:Object = new JSONDecoder(messageStr).getValue();
				var obj:Object = JsonUtil.decode(messageStr);
				if(obj.t == undefined || (obj.t is String) == false)
				{
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
						message = new LoadMessageVO();
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