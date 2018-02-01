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

		
		public var type:int;
		public var key:String='';
		public var items:ArrayCollection= new ArrayCollection();
		
		public function getItem(key:String):GlueMessageItem{
			if(!items || items.length==0) return null;
			return ArrayUtil.searchItem('key',key,items.source) as GlueMessageItem; 
		}

	}
}