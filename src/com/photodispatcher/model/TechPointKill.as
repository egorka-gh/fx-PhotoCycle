package com.photodispatcher.model{
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.CBoxGridItemEditor;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;
	
	public class TechPointKill extends DBRecord{

		//db fileds
		[Bindable]
		public var id:int;
		[Bindable]
		public var tech_type:int;
		[Bindable]
		public var name:String;

		//db drived
		[Bindable]
		public var tech_type_name:String;
		[Bindable]
		public var tech_state:int;
		[Bindable]
		public var tech_book_part:int;

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn= new GridColumn('id'); col.headerText='ID'; col.visible=false; result.addItem(col);
			col= new GridColumn('name'); col.headerText='Наименование'; result.addItem(col); 
			col= new GridColumn('tech_type'); col.headerText='Тип'; col.labelFunction=GridUtil.idToLabel; col.itemEditor=new ClassFactory(CBoxGridItemEditor); result.addItem(col);
			return result;
			
		}

	}
}