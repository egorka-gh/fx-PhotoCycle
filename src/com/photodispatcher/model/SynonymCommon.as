package com.photodispatcher.model{
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;

	public class SynonymCommon  extends DBRecord{
		//db fileds
		[Bindable]
		public var id:int;
		[Bindable]
		public var item_id:int;
		[Bindable]
		public var synonym:String;

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('id'); col.headerText='id'; col.visible=false; result.addItem(col);
			col= new GridColumn('synonym'); col.headerText='Синоним'; result.addItem(col);
			return result;
		}

	}
}