package com.photodispatcher.model{
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;
	
	public class EndpaperKill extends DBRecord{
		//db fileds
		[Bindable]
		public var id:int=-1;
		[Bindable]
		public var name:String='';
		
		public function get isEmpty():Boolean{
			return id==0;
		}

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn= new GridColumn('id'); col.headerText='ID'; col.visible=false; result.addItem(col);
			col= new GridColumn('name'); col.headerText='Наименование'; result.addItem(col); 
			return result;
		}

	}
}