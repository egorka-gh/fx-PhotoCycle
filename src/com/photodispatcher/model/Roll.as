package com.photodispatcher.model{
	import com.photodispatcher.model.dao.RollDAO;

	public class Roll extends DBRecord{
		private static var itemsMap:Object;
		
		public static function initItemsMap():void{
			var dao:RollDAO=new RollDAO();
			var a:Array=dao.findAllArray();
			if(!a) return;
			itemsMap=new Object();
			for each(var o:Object in a){
				var s:Roll= o as Roll;
				if(s){
					itemsMap[s.width.toString()]=s;
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