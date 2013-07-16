package com.jxl.chat.vo.messages
{
	import com.adobe.serialization.json.JSONEncoder;
	
	public class ACKMessageVO extends AbstractMessageVO
	{
		public var ackMessageID:uint = 0;
		
		public function ACKMessageVO()
		{
			super();
			
			_type = MessageTypes.ACK;
		}
		
		override protected function toRaw():Object{
			var o:Object=super.toRaw();
			o.aid=ackMessageID;
			return o;
		}
		
		
		/*
		public override function toJSON():String
		{
			var obj:Object = {id: id, t: _type, aid: ackMessageID};
			//return JSON.encode(obj);
			return new JSONEncoder(obj).getString();
		}
		*/
		
		
		public override function fromRaw(jsonObject:Object):void{
			/*
			_id					= jsonObject.id;
			_type				= jsonObject.t;
			*/
			super.fromRaw(jsonObject);
			ackMessageID		= jsonObject.aid;
		}
		
		public override function toString():String
		{
			var str:String 			= "";
			str						+= "[class ACKMessageVO ";
			str						+= "id=" + id;
			str						+= ", type=" + _type;
			str						+= ", ackMessageID=" + ackMessageID;
			str						+= "]";
			return str;
		}

	}
}