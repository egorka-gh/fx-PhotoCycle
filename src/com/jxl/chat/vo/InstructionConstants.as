package com.jxl.chat.vo{
	public class InstructionConstants{
		
		public static const CLIENT_SET_USERNAME:String							= "clientSetUsername";
		public static const CLIENT_SET_USERTYPE:String							= "clientSetUserType";
		public static const CLIENT_CHAT_MESSAGE:String							= "clientChatMessage";
		public static const CLIENT_PING_RESPONSE:String							= "clientPingResponse";
		public static const CLIENT_BUILD_REJECT:String							= "clientBuildReject";
		public static const CLIENT_BUILD_CONFIRM:String							= "clientBuildConfirm";
		public static const CLIENT_BUILD_COMPLETE:String						= "clientBuildComplete";
		public static const CLIENT_LOAD_REJECT:String							= "clientLoadReject";
		public static const CLIENT_LOAD_CONFIRM:String							= "clientLoadConfirm";
		public static const CLIENT_LOAD_PROGRESS:String							= "clientLoadProgress";
		public static const CLIENT_LOAD_COMPLETE:String							= "clientLoadComplete";
		
		public static const SERVER_CLIENT_CONNECTED:String						= "serverClientConnected";
		public static const SERVER_CLIENT_CONNECTED_TO_CHAT:String				= "serverClientConnectedToChat";
		public static const SERVER_CLIENT_ALREADY_IN_CHAT:String				= "serverClientAlreadyInChat";
		public static const SERVER_CLIENT_CHAT_MESSAGE:String					= "serverClientChatMessage";
		public static const SERVER_UKNOWN_CLIENT_MESSAGE:String					= "serverUnknownClientMessage";
		public static const SERVER_CLIENT_DISCONNECTED:String					= "serverClientDisconnected";
		public static const SERVER_UPDATED_USER_LIST:String						= "serverUpdatedUserList";
		public static const SERVER_USER_BOOTED:String							= "serverUserBooted";
		public static const SERVER_USERNAME_TAKEN:String						= "serverUsernameTaken";
		public static const SERVER_PING:String									= "serverPing";
		public static const SERVER_BUILD_POST:String							= "serverBuildPost";
		public static const SERVER_LOAD_POST:String								= "serverLoadPost";
		public static const SERVER_LOAD_STOP:String								= "serverLoadStop";
		public static const SERVER_SET_USERTYPE:String							= "serverSetUserType";
	}
}