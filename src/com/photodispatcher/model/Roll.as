package com.photodispatcher.model{
	import com.photodispatcher.model.dao.RollDAO;

	public class Roll extends DBRecord{
		private static var _itemsMap:Object;

		public static function get itemsMap():Object{
			if(_itemsMap) return _itemsMap;
			initItemsMap();
			return _itemsMap;
		}
		
		public static function initItemsMap():void{
			var dao:RollDAO=new RollDAO();
			var a:Array=dao.findAllArray();
			if(!a) return;
			_itemsMap=new Object();
			for each(var o:Object in a){
				var s:Roll= o as Roll;
				if(s){
					_itemsMap[s.width.toString()]=s;
				}
			}
		}

		//db fileds
		[Bindable]
		public var width:int;
		[Bindable]
		public var pixels:int;
		
	}
}