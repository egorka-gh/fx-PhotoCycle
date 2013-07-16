package com.jxl.chatserver.events{
	import com.jxl.chat.vo.messages.ChatMessageVO;
	import com.jxl.chatserver.vo.ClientVO;
	
	import flash.events.Event;
	import flash.net.Socket;

	public class ServiceEvent extends Event{
		
		public static const CHAT_SERVER_SERVICE_CONNECTED:String			= "chatServerServiceConnected";
		public static const CHAT_SERVER_SERVICE_ERROR:String				= "chatServerServiceError";
		public static const CHAT_SERVER_SERVICE_DISCONNECTED:String			= "chatServerServiceDisconnected";

		public static const CHAT_SERVER_SERVICE_USER_ONLINE:String			= "chatServerServiceUserOnline";
		public static const CHAT_SERVER_SERVICE_USER_OFFLINE:String			= "chatServerServiceUserOffline";
		public static const CHAT_SERVER_SERVICE_USER_MESSAGE:String			= "chatServerServiceUserMessage";
		public static const CHAT_SERVER_SERVICE_SERVER_MESSAGE:String		= "chatServerServiceServerMessage";

		public var lastError:String;
		public var user:ClientVO;
		public var message:ChatMessageVO;
		
		public function ServiceEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false){
			super(type, bubbles, cancelable);
		}
		
	}
}