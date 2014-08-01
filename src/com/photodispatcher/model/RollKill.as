package com.photodispatcher.model{
	import com.photodispatcher.model.dao.RollDAO;

	public class RollKill extends DBRecord{
		private static var _itemsMap:Object;

		public static function itemsMap():Object{
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
		
		public static function getStandartWidth(pix:int):int{
			var map:Object=itemsMap();
			if(!map) return 0;
			var r:Roll;
			var result:Roll;
			for each(r in map){
				if(r.pixels==pix) return r.width;
				if(r.pixels>pix){
					if(!result || result.pixels>r.pixels) result=r;
				}
			}
			return result?result.width:0;
		}

		//db fileds
		[Bindable]
		public var width:int;
		[Bindable]
		public var pixels:int;
		
	}
}