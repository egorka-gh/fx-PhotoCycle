package com.jxl.chatserver.vo{
	import com.jxl.chat.net.MessageSocket;
	
	public class ClientVO{
		public static const TYPE_COMMON:int=0;
		public static const TYPE_MANAGER:int=1;
		public static const TYPE_LAB:int=2;
		public static const TYPE_BUILDER:int=3;
		public static const TYPE_LOADER:int=4;
		public static const TYPE_HELPER:int=5;
		public static const TYPE_TROLL:int=6;

		public static const HELPER_MODES:Array=[{id:TYPE_BUILDER, label:'Обработчик'},{id:TYPE_LOADER, label:'Загрузчик'},{id:TYPE_HELPER, label:'Универсал'},{id:TYPE_TROLL, label:'Бездельник'}];
		
		private static var helperModesMap:Object;
		public static function modeName(mode:int):String{
			if(!helperModesMap){
				helperModesMap= new Object;
				helperModesMap[TYPE_BUILDER]='Обработчик';
				helperModesMap[TYPE_LOADER]='Загрузчик';
				helperModesMap[TYPE_HELPER]='Универсал';
				helperModesMap[TYPE_TROLL]='Бездельник';
			}
			return helperModesMap[mode];
		}

		private var _messageSocket:MessageSocket;
		public function get messageSocket():MessageSocket{
			return _messageSocket;
		}
		public function set messageSocket(value:MessageSocket):void{
			_messageSocket = value;
			if(_messageSocket && _messageSocket.socket){
				userIP=_messageSocket.socket.remoteAddress;
			}
		}
		public var username:String;
		[Bindable]
		public var userType:int;
		public var userIP:String; //invalid for lockal user
	
		public function ClientVO(messageSocket:MessageSocket, username:String, userType:int=TYPE_COMMON):void{
			this.messageSocket 		= messageSocket;
			this.username			= username;
			this.userType			= userType;
		}
		
		public function clone():ClientVO
		{
			return new ClientVO(messageSocket, username);
		}

	}
}