/**
 * Generated by Gas3 v2.3.2 (Granite Data Services).
 *
 * NOTE: this file is only generated if it does not exist. You may safely put
 * your custom code here.
 */

package com.photodispatcher.model.mysql.entities {
	import mx.collections.ArrayCollection;
	
	import org.granite.reflect.Field;
	import org.granite.reflect.Type;

    [Bindable]
    [RemoteClass(alias="com.photodispatcher.model.mysql.entities.OrderExtraInfo")]
    public class OrderExtraInfo extends OrderExtraInfoBase {
		public static const MESSAGE_TYPE_GROUP:int=1;
		public static const MESSAGE_TYPE_ORDER:int=2;
		
		public var rawMessagesGroup:String;
		public var rawMessagesOrder:String;
		
		public function get isEmpty():Boolean{
			var result:Boolean=true;
			var type:Type= Type.forClass(OrderExtraInfo);
			var props:Array=type.properties;
			if(!props || props.length==0) return result;
			var prop:Field;
			for each(prop in props){
				if(this[prop.name]){
					result=false;
					break;
				}
			}
			return result;
		}

		public function parseMessages():void{
			if(!id) return;
			messagesLog= new ArrayCollection();
			_parseMessages(MESSAGE_TYPE_GROUP, rawMessagesGroup);
			_parseMessages(MESSAGE_TYPE_ORDER, rawMessagesOrder);
		}
		
		private function _parseMessages(type:int, raw:String):void{
			if(!raw) return;
			var str:String=raw.replace(String.fromCharCode(13),'');
			var arr:Array=str.split(String.fromCharCode(10));
			var subArr:Array;
			var subStr:String;
			var it:OrderExtraMessage;
			for each(subStr in arr){
				subArr=subStr.split('|');
				if(subArr && subArr.length>2 && subArr[0]){
					it= new OrderExtraMessage();
					it.id=id;
					it.sub_id=(sub_id?sub_id:'');
					it.msg_type=type;
					it.lod_key=subArr[0];
					it.log_user=subArr[1];
					it.message=subArr[2];
					it.persistState=AbstractEntity.PERSIST_NEW;
					messagesLog.addItem(it);
				}
			}
		}

    }
}