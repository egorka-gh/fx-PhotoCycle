package com.photodispatcher.model{
	import com.akmeful.fotokniga.library.admin.CalcAdminLibrary;
	import com.photodispatcher.util.GridUtil;
	import com.photodispatcher.view.itemRenderer.BooleanGridItemEditor;
	import com.photodispatcher.view.itemRenderer.BooleanGridRenderer;
	import com.photodispatcher.view.itemRenderer.TimeGridEditor;
	
	import flash.globalization.DateTimeStyle;
	
	import mx.collections.ArrayList;
	import mx.core.ClassFactory;
	
	import spark.components.gridClasses.GridColumn;
	import spark.formatters.DateTimeFormatter;

	public class LabTimetableKill extends DBRecord{
		//db fileds
		[Bindable]
		public var lab_device:int;
		[Bindable]
		public var day_id:int;
		[Bindable]
		public var time_from:Date;
		[Bindable]
		public var time_to:Date;
		[Bindable]
		public var is_online:Boolean;

		//db drived
		[Bindable]
		public var day_id_name:String;

		public static function gridColumns():ArrayList{
			var result:ArrayList= new ArrayList();
			var col:GridColumn;
			col= new GridColumn('is_online'); col.headerText=' '; col.itemRenderer=new ClassFactory(BooleanGridRenderer); col.editable=false;  col.width=30; result.addItem(col);
			col= new GridColumn('day_id_name'); col.headerText='День недели'; col.editable=false; result.addItem(col);
			var fmt:DateTimeFormatter=new DateTimeFormatter(); fmt.dateTimePattern='HH:mm'; fmt.useUTC=false;
			col= new GridColumn('time_from'); col.headerText='С'; col.formatter=fmt; col.itemEditor=new ClassFactory(TimeGridEditor); col.width=100; result.addItem(col);
			col= new GridColumn('time_to'); col.headerText='До'; col.formatter=fmt; col.itemEditor=new ClassFactory(TimeGridEditor);  col.width=100; result.addItem(col);
			return result;
		}

	}
}