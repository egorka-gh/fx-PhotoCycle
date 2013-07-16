package com.jxl.chatclient.events
{
	import com.jxl.chat.vo.messages.ChatMessageVO;
	
	import flash.events.Event;

	public class ServiceEvent extends Event
	{
		public static const CONNECTED:String			= "connected";
		public static const ERROR:String				= "error";
		public static const CHAT_MESSAGE:String			= "chatMessage";
		public static const JOINED_CHAT:String			= "joinedChat";
		public static const DISCONNECTED:String			= "disconnected";
		public static const USER_LIST_UPDATED:String	= "userListUpdated";
		public static const USER_JOINED_CHAT:String		= "userJoinedChat";
		public static const USER_LEFT_CHAT:String		= "userLeftChat";
		public static const USERNAME_TAKEN:String		= "usernameTaken";
		
		public var chatMessage:ChatMessageVO;
		public var userList:Array;
		public var lastError:String;
		
		public function ServiceEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
	}
}