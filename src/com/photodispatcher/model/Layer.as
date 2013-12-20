package com.photodispatcher.model{
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;

	public class Layer extends DBRecord{
		public static const LAYER_EMPTY:int=0;
		public static const LAYER_SHEET:int=1;
		public static const LAYER_ENDPAPER:int=2;

		
		//db fileds
		[Bindable]
		public var id:int=-1;
		[Bindable]
		public var name:String;
		
		/*
		//runtime
		private var currentTrayIdx:int=-1;
		private var trays:Array;

		public function get currentTray():int{
			if(currentTrayIdx<0 || !trays || trays.length==0) return -1;
			return int(trays[currentTrayIdx]);
		}
		public function nextTray():int{
			if(currentTrayIdx<0 || !trays || trays.length==0) return -1;
			currentTrayIdx++;
			if(currentTrayIdx>=trays.length) currentTrayIdx=0;
			return currentTray;
		}
		
		public function addTray(num:int):void{
			if(!trays) trays=[];
			if(num<0) return;
			if(currentTrayIdx<0) currentTrayIdx=0;
			trays.push(num);
		}
		*/
		
		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn= new GridColumn('id'); col.headerText='ID'; col.visible=false; result.addItem(col);
			col= new GridColumn('name'); col.headerText='Наименование'; result.addItem(col); 
			return result;
			
		}

	}
}