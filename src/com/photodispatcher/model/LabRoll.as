package com.photodispatcher.model{
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.BooleanGridRenderer;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;
	
	public class LabRoll extends Roll{

		//db fileds
		[Bindable]
		public var lab_device:int;
		[Bindable]
		public var paper:int;
		[Bindable]
		public var len_std:int;
		[Bindable]
		public var len:int;
		[Bindable]
		public var is_online:Boolean;
		
		//use in device (edit in full list mark)
		[Bindable]
		public var is_used:Boolean;

		//db drived
		[Bindable]
		public var paper_name:String;

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('is_used'); col.headerText=' '; col.itemRenderer=new ClassFactory(BooleanGridRenderer); col.width=30; result.addItem(col);
			col= new GridColumn('width'); col.headerText='Ширина'; col.editable=false; result.addItem(col);
			col= new GridColumn('paper_name'); col.headerText='Бумага'; col.editable=false; result.addItem(col);
			col= new GridColumn('len_std'); col.headerText='Длинна (мм)'; result.addItem(col);
			return result;
		}

	}
}