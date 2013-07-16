package com.jxl.chat.vo.messages{
	import com.photodispatcher.model.Order;

	public class BuildMessageVO extends ChatMessageVO{
		
		public var order:Order;
		public var hasError:Boolean=false;
		public var errorMsg:String='';
		
		public function BuildMessageVO(){
			super();
			_type = MessageTypes.BUILD;
		}
		
		override protected function toRaw():Object{
			var o:Object=super.toRaw();
			o.hasError=hasError?1:0;
			o.errorMsg=errorMsg;
			if(order) o.order=order.toRaw();
			return o;
		}
		
		public override function fromRaw(jsonObject:Object):void{
			super.fromRaw(jsonObject);
			hasError=Boolean(jsonObject.hasError);
			errorMsg=jsonObject.errorMsg;
			order=Order.fromRaw(jsonObject.order);
		}

	}
}