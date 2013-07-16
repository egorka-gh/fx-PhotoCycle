package com.jxl.chat.vo.messages
{
	import com.adobe.serialization.json.JSONEncoder;
	import com.jxl.chatserver.vo.ClientVO;
	
	public class ChatMessageVO extends AbstractMessageVO
	{
		
		public var message:*;
		public var instructions:String;
		public var username:String;
		public var userType:int;
		
		public function ChatMessageVO(instructions:String='',message:*=null,username:String='', userType:int=0){
			super();
			_type = MessageTypes.CHAT;
			this.instructions=instructions;
			this.message=message;
			this.username=username;
			this.userType=userType;
		}
		
		/*
		public override function toJSON():String{
			var obj:Object = {id: id, m: message, u: username, i: instructions, t: _type, ut:userType};
			//return JSON.encode(obj);
			return new JSONEncoder(obj).getString();
		}
		*/

		override protected function toRaw():Object{
			var o:Object=super.toRaw();
			o.m=message;
			o.u=username;
			o.i=instructions;
			o.ut=userType;
			return o;
		}

		public override function fromRaw(jsonObject:Object):void{
			super.fromRaw(jsonObject);
			//_id					= jsonObject.id;
			message 			= jsonObject.m;
			username 			= jsonObject.u;
			userType=jsonObject.ut;
			instructions		= jsonObject.i;
			//_type				= jsonObject.t;
		}
		
		public override function toString():String
		{
			var str:String 			= "";
			str						+= "[class ChatMessageVO ";
			str						+= "id=" + id;
			str						+= ", type=" + _type;
			str						+= ", instructions=" + instructions;
			str						+= ", username=" + username;
			str 					+= ", message=" + message;
			str						+= "]";
			return str;
		}

	}
}