package com.photodispatcher.service.glue{
	import com.photodispatcher.util.ArrayUtil;

	public class GlueMessageBlock{
		public var key:String='';
		public var items:Array=[];
		
		public function getItem(key:String):GlueMessageItem{
			if(!items || items.length==0) return null;
			return ArrayUtil.searchItem('key',key,items) as GlueMessageItem; 
		}

	}
}