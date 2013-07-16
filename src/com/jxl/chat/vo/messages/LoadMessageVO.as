package com.jxl.chat.vo.messages{
	public class LoadMessageVO extends BuildMessageVO{
		public var filesTotal:int=0;
		public var filesDone:int=0;
		public var speed:Number=0;

		public function LoadMessageVO(){
			super();
			_type = MessageTypes.LOAD;
		}
		
		override protected function toRaw():Object{
			var o:Object=super.toRaw();
			o.filesTotal=filesTotal;
			o.filesDone=filesDone;
			o.speed=speed;
			return o;
		}
		
		public override function fromRaw(jsonObject:Object):void{
			super.fromRaw(jsonObject);
			filesTotal=jsonObject.filesTotal;
			filesDone=jsonObject.filesDone;
			speed=jsonObject.speed;
		}

	}
}