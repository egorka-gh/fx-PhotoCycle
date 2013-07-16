package com.jxl.chat.vo.messages
{
	public class UnknownMessageVO extends AbstractMessageVO
	{
		public var json:String;
		
		public function UnknownMessageVO()
		{
			super();
		}
		
		public override function toString():String
		{
			var str:String 			= "";
			str						+= "[class UnknownMessageVO ";
			str						+= "id=" + id;
			str						+= ", type=" + type;
			str						+= ", json=" + json;
			str						+= "]";
			return str;
		}
		
	}
}