package com.photodispatcher.service.glue{
	import com.photodispatcher.util.ArrayUtil;
	
	import mx.collections.ArrayCollection;

	[Bindable]
	public class GlueMessageBlock{
		
		public static const TYPE_NONE:int=0;
		public static const TYPE_BUTTON:int=1;
		public static const TYPE_STATUS:int=2;
		public static const TYPE_PRODUCT:int=3;
		public static const TYPE_MESSAGE:int=4;

		public static const TYPE_LABELS:ArrayCollection=new ArrayCollection(['','Кнопки','Статусы','Продукт','Сообщения']);

		
		public var type:int;
		public var key:String='';
		public var items:ArrayCollection= new ArrayCollection();
		
		public function getItem(bykey:String):GlueMessageItem{
			if(!items || items.length==0) return null;
			return ArrayUtil.searchItem('key',bykey,items.source) as GlueMessageItem; 
		}

		public function getItemIdx(bykey:String):int{
			if(!items || items.length==0) return -1;
			return ArrayUtil.searchItemIdx('key',bykey,items.source); 
		}

		public function replaceItem(item:GlueMessageItem):void{
			if(!items) items= new ArrayCollection();
			var idx:int=ArrayUtil.searchItemIdx('key',item.key,items.source);
			if(idx==-1){
				items.addItem(item);
			}else{
				items.setItemAt(item,idx);
			}
		}

		public function clone():GlueMessageBlock{
			var b:GlueMessageBlock= new GlueMessageBlock();
			b.type=this.type;
			b.key=this.key;
			return b;
		}

	}
}