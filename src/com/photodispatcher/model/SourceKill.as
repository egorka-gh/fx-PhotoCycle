package com.photodispatcher.model{
	import com.photodispatcher.context.Context;
	import com.photodispatcher.model.mysql.entities.Source;
	import com.photodispatcher.model.mysql.entities.SourceSvc;
	import com.photodispatcher.util.StrUtil;
	
	import flash.filesystem.File;
	
	import mx.collections.ArrayList;
	
	import spark.components.gridClasses.GridColumn;

	[Bindable]
	public class SourceKill extends com.photodispatcher.model.mysql.entities.Source{ //extends DBRecord
		public static const LOCATION_TYPE_SOURCE:int=1;
		public static const LOCATION_TYPE_LAB:int=2;
		public static const LOCATION_TYPE_TECH_POINT:int=3;
		
		public static function gridColumns(labColumns:Boolean=false):ArrayList{
			var result:ArrayList= new ArrayList();
			
			var col:GridColumn= new GridColumn('id'); col.headerText='ID'; result.addItem(col);
			col= new GridColumn('name'); col.headerText='Наименование'; result.addItem(col); 
			col= new GridColumn('type_name'); col.headerText='Тип'; result.addItem(col); 
			col= new GridColumn('online'); col.headerText='Online'; result.addItem(col); 
			if(!labColumns){
				col= new GridColumn('code'); col.headerText='Код'; result.addItem(col); 
			}
			return result;
		}

	}
}